    seem = require 'seem'
    nimble = require 'nimble-direction'
    pkg = require '../package.json'
    EventEmitter = require 'events'
    moment = require 'moment-timezone'
    uuidV4 = require 'uuid/v4'
    @name = "#{pkg.name}:middleware:setup"
    assert = require 'assert'
    FS = require 'esl'

    Redis = require 'redis'
    Bluebird = require 'bluebird'
    Bluebird.promisifyAll Redis.RedisClient.prototype
    Bluebird.promisifyAll Redis.Multi.prototype

    seconds = 1000
    minutes = 60*seconds

    @config = seem ->
      yield nimble @cfg
      assert @cfg.prov?, 'Nimble did not inject cfg.prov'

    @server_pre = seem ->
      yield nimble @cfg
      assert @cfg.prov?, 'Nimble did not inject cfg.prov'

      if @cfg.redis?
        @cfg.redis_client = redis = Redis.createClient @cfg.redis
        redis.on 'error', (error) =>
          @debug "redis: #{error.command} #{error.args?.join(' ')}: #{error.stack ? error}"
        redis.on 'ready', => @debug "redis: ready"
        redis.on 'connect', => @debug "redis: connect"
        redis.on 'reconnecting', => @debug "redis: reconnecting"
        redis.on 'end', => @debug "redis: end"
        redis.on 'warning', => @debug "redis: warning"

      if @cfg.local_redis?
        @cfg.local_redis_client = local_redis = Redis.createClient @cfg.local_redis
        local_redis.on 'error', (error) =>
          @debug "local redis: #{error.command} #{error.args?.join(' ')}: #{error.stack ? error}"
        local_redis.on 'ready', => @debug "local redis: ready"
        local_redis.on 'connect', => @debug "local redis: connect"
        local_redis.on 'reconnecting', => @debug "local redis: reconnecting"
        local_redis.on 'end', => @debug "local redis: end"
        local_redis.on 'warning', => @debug "local redis: warning"

      @cfg.period_of ?= (stamp = new Date(),timezone = 'UTC') ->
        moment
        .tz stamp, timezone
        .format 'YYYY-MM'

      @cfg.reference_id ?= =>
        uuid = uuidV4()
        period = @cfg.period_of null
        id = "#{period}-#{uuid}"

Use redis to retrieve the server on which this call should be hosted, and set it to `local_server` if none was previously set.
Returns either:
- `false` to indicate the call should be handled locally;
- the value previously stored if it is available;
- `null` if the determination could not be made (for example due to parameter, configuration, or server error).

If the `local_server` parameter is not provided (it normally should), only the previously stored value is checked. This should never be used when dealing with calls, since it means the call might not go through.

      @cfg.is_remote = seem (name,local_server) =>

        unless name?
          return null

        unless redis?
          @debug.dev 'is_remote: Missing redis'
          return null

Just probing (this is only useful when retrieving data, never when handling calls).

        if not local_server?
          server = yield redis
            .getAsync key
            .catch (error) ->
              @debug.ops "error #{error.stack ? error}"
              null

          switch server?.substring 0, @cfg.host.length
            when null
              return null
            when @cfg.host
              return false
            else
              return server

        server = local_server

Set if not exists, [setnx](https://redis.io/commands/setnx)
(Note: there's also hsetnx/hget which could be used for this, not sure what's best practices.)

        key = "server for #{name}"

        first_time = yield redis
          .setnxAsync key, server
          .catch (error) ->
            @debug.ops "error #{error.stack ? error}"
            null

        if not first_time
          server = yield redis
            .getAsync key
            .catch (error) ->
              @debug.ops "error #{error.stack ? error}"
              null

Check whether handling is local (assuming FreeSwitch is co-hosted, which is our standard assumption).

        @debug 'Checking for local handling', server, local_server

        switch server

          when null
            @debug.ops 'Redis failed'
            return null

          when local_server
            @debug 'Handling is local'
            return false

          else
            @debug 'Handling is remote'
            return server

These methods parallel the ones in black-metal/api.
Eventually the two should be merged.

Create a new socket client

      @cfg._client = _client = =>
        new Promise (resolve) =>
          try
            client = FS.client ->
              resolve this
            client.keepConnected (@cfg.socket_port ? 5722), '127.0.0.1'
          catch error
            @debug '_client: error', error
            resolve null
          return

Create a new socket client bound to a given UUID

      @cfg.uuid_client = seem (uuid) ->
        client = yield _client()
        yield client.send "myevents #{uuid} json"
        yield client.event_json 'ALL'
        yield client.linger()
        # yield client.auto_cleanup() # Already done by esl
        client

Use a default client for generic / shared APIs

      default_client = null

      @cfg.api = seem (cmd) ->
        default_client ?= yield _client()
        res = yield default_client.api cmd
        res?.body ? null

      return

    @web = ->
      @cfg.versions[pkg.name] = pkg.version

    @notify = ->

      @cfg.statistics.on 'reference', (data) =>

The `reference` event is pre-registered (in spicy-action) on the `calls` bus.

        @socket.emit 'reference', data

      @cfg.statistics.on 'report', (data) =>

The `call` event is pre-registered (in spicy-action) on the `calls` bus.
It receives a notification via the `@notify` method; the notification contains information about the call status, including the report data that triggered the notification.

        @socket.emit 'call', data

Standard events: `add`.

      if @cfg.notify_statistics
        @cfg.statistics.on 'add', (data) =>
          @socket.emit 'statistics:add',
            host: cfg.host
            key: data.key
            value: data.value.toJSON()

      @on_connexion = (init) =>

Run on re-connections (`welcome` is sent by spicy-action when we connect).

        @socket.on 'welcome', init

Run manually when we start (the `welcome` message has probably already been seen).

        init()

Register a new event on the bus.

      @register = (event,default_room = null) =>
        @on_connexion =>
          @debug 'Register', {event, default_room}
          @socket.emit 'register', {event,default_room}

Configure our client to receive specific queues.

      @socket.on 'configured', (data) =>
        @debug 'Socket configured', data

      @configure = (options) =>
        @on_connexion =>
          @debug 'Configure', options
          @socket.emit 'configure', options

      @socket.on 'connect', =>
        @debug.ops 'connect'
      @socket.on 'connect_error', =>
        @debug.ops 'connect_error'
      @socket.on 'disconnect', =>
        @debug.ops 'disconnect'

      return

    @include = (ctx) ->

      @session.reports = []

      ctx[k] = v for own k,v of {
        statistics: @cfg.statistics

        sleep: (timeout) ->
          new Promise (resolve) ->
            setTimeout resolve, timeout

        direction: (direction) ->
          @session.direction = direction
          @call.emit 'direction', direction
          @tag "direction:#{direction}"
          @report {event:'direction', direction}

`@_in()`: Build a list of target rooms for event reporting (as used by spicy-action).

        _in: (_in = [])->

Add any endpoint- or number- specific dispatch room (this allows end-users to receive events for endpoints and numbers they are authorized to monitor).

          push_in = (room) ->
            return if not room? or room in _in
            _in.push room

We assume the room names match record IDs.

          push_in @session.endpoint?._id
          if @session.number?.endpoint?
            push_in ['endpoint',@session.number?.endpoint].join ':'
          push_in @session.number?._id
          push_in @session.e164_number?._id
          if @session.number_domain_data?.dialplan is 'centrex'
            push_in @session.number_domain_data._id

          if @session.reference_data?.tags?
            for tag in @session.reference_data.tags when tag.match /^\w+:/
              push_in tag

          _in

Data reporting (e.g. to save for managers reports).
Typically `@report({state,…})` for calls, `@report({event,…})` for non-calls.

        report: (report) ->
          unless @call? and @session?
            @debug.dev 'report: improper environment'
            return

          report.timestamp = new Date().toJSON()
          report.source ?= @source
          report.destination ?= @destination
          report.direction ?= @session.direction
          report.dialplan ?= @session.dialplan
          report.country ?= @session.country
          report.number_domain ?= @session.number_domain

          report.call = @call.uuid
          report.session = @session._id
          report.reference = @session.reference
          report.report_type = 'in-call'

          @session.reports.push report

        save_reports: (reports) ->
          unless @call? and @session?
            @debug.dev 'report: improper environment'
            return

          if yield @cfg.save_reports? @session.reports
            @session.reports = []

          return

Real-time notification (e.g. to show on a web panel).

        notify: (report) ->

The report is first saved as usual.

          @report report

The notification is really about the call progress so far.

          notification =
            call: @call.uuid
            session: @session._id
            reports: @session.reports
            reference_data: @session.reference_data
            _in: @_in()
            host: @cfg.host

          for own k,v of report
            notification[k] = v

          @call.emit 'report', notification
          @cfg.statistics.emit 'report', notification

        save_call: seem ->
          if @cfg.update_call_data?
            {call_data} = @session
            call_data = yield @cfg.update_call_data call_data
            @cfg.statistics.emit 'call', call_data
            @session.call_data = call_data
          else
            @debug.dev 'Missing @cfg.update_call_data, not saving'

        save_ref: seem ->
          if @cfg.update_reference_data?
            {reference_data} = @session
            reference_data = yield @cfg.update_reference_data reference_data
            @cfg.statistics.emit 'reference', reference_data
            @session.reference_data = reference_data
          else
            @debug.dev 'Missing @cfg.update_reference_data, not saving'

        get_ref: seem ->
          @session.reference ?= @cfg.reference_id()
          {reference} = @session
          if @cfg.get_reference_data?
            @debug 'Loading reference_data', reference
            @session.reference_data ?= yield @cfg.get_reference_data reference
          else
            @session.reference_data ?= { reference }
            @debug.dev 'Missing @cfg.get_reference_data, using empty reference_data', reference

        save_trace: ->
          @cfg.update_trace_data? @session

        set: seem (name,value) ->
          return unless name?

          if typeof name is 'string'
            yield @res.set name, value
            return

          for own k,v of name
            yield @res.set k, v

          return

        unset: seem (name) ->
          return unless name?

          if typeof name is 'string'
            yield @res.set name, null
            return

          for k in name
            yield @res.set k, null

          return

        export: seem (name,value) ->
          return unless name?

          if typeof name is 'string'
            yield @res.export name, value
            return

          for own k,v of name
            yield @res.export k, v

          return

        respond: (response) ->
          @statistics?.add ['immediate-response',response]
          @notify state: 'immediate-response', response: response
          @session.first_response_was ?= response

Prevent extraneous processing of this call.

          @direction 'responded'
          @tag "response:#{response}"

          if @session.alternate_response?
            @session.alternate_response response
          else
            ctx.action 'respond', response

        sofia_string: seem (number, extra_params = []) ->

          @debug 'sofia_string', number, extra_params

          id = "number:#{number}@#{@session.number_domain}"

          number_data = yield @cfg.prov
            .get id
            .catch (error) ->
              @debug.ops "#{id} #{error.stack ? error}"
              {}

          return '' unless number_data.number?

This is a simplified version of the sofia-target (session.initial_destinations) building code found in middleware:client:ingress:post.

          destination = number_data.number.split('@')[0]

          to_uri = "sip:#{number_data.endpoint}"

          unless to_uri.match /@/
            to_uri = "sip:#{destination}@#{@cfg.ingress_target}"

          if number_data.endpoint_via?
            extra_params.push "sip_network_destination=#{number_data.endpoint_via}"

This is a simplified version of the sofia-string building code found in middleware:client:ingress:send.

* hdr.X-CCNQ3-Endpoint Endpoint name, set when dialing numbers.
* hdr.X-CCNQ3-Number-Domain Number domain name, set when dialing numbers.

          params = [
            extra_params...
            "sip_h_X-CCNQ3-Endpoint=#{number_data.endpoint}"
            "sip_h_X-CCNQ3-Number-Domain=#{@session.number_domain}"
          ]

          "[#{params.join ','}]sofia/#{@session.sip_profile}/#{to_uri}"

        validate_local_number: seem ->

Retrieve number data.

* session.number (object) The record of the destination number interpreted as a local-number in `session.number_domain`.
* doc.local_number.disabled (boolean) If true the record is not used.

          dst_number = "#{@destination}@#{@session.number_domain}"
          @session.number = yield @cfg.prov
            .get "number:#{dst_number}"
            .catch (error) -> {disabled:true,error}
          @tag @session.number._id
          @user_tags @session.number.tags
          if @session.number.timezone?
            @session.timezone ?= @session.number.timezone
          if @session.number.music?
            @session.music ?= @session.number.music

          if @session.number.error?
            @debug "Could not locate destination number #{dst_number}"
            @tag 'invalid-local-number'
            yield @respond '486 Not Found'
            return

          @debug "validate_local_number: Got dst_number #{dst_number}", @session.number

          if @session.number.disabled
            @debug "Number #{dst_number} is disabled"
            @tag 'disabled-local-number'
            @notify state:'disabled-local-number', number: @session.number._id
            yield @respond '486 Administratively Forbidden' # was 403
            return

Set the endpoint name so that if we redirect to voicemail the voicemail module can locate the endpoint.

          @session.endpoint_name = @session.number.endpoint
          @session.reference_data.endpoint = @session.number.endpoint

Set the account so that if we redirect to an external number the egress module can find it.

          @session.reference_data.account = @session.number.account
          @tag "account:#{@session.reference_data.account}"
          @report
            state:'validated-local-number'
            number: @session.number._id
            endpoint: @session.endpoint_name
            account: @session.reference_data.account
          yield @save_ref()

          dst_number

        redis: @cfg.redis_client
        local_redis: @cfg.local_redis_client

        tag: (tag) ->
          @session.reference_data?.tags?= []
          if tag?
            @session.reference_data?.tags.push tag
            @report {event:'tag', tag}

        user_tag: (tag) ->
          if tag?
            @tag "user-tag:#{tag}"
            @report {event:'user-tag', tag}

        user_tags: (tags) ->
          return unless tags?
          for tag in tags
            @user_tag tag

        has_tag: (tag) ->
          @session.reference_data?.tags? and tag in @session.reference_data.tags

        has_user_tag: (tag) ->
          tag? and @has_tag "user-tag:#{tag}"

        record_call: (name) ->
          unless @cfg.recording_uri?
            @debug.dev 'No recording_uri, call will not be recorded.'
            return false

Keep recording (async)

          keep_recording = seem =>
            @notify event:'recording'
            uri = yield @cfg.recording_uri name
            @debug 'Recording', @call.uuid, uri
            outcome = yield @cfg.api "uuid_record #{@call.uuid} start #{uri}"
            @debug 'Recording', @call.uuid, uri, outcome

            last_uri = uri

            still_running = true
            @call.once 'CHANNEL_HANGUP_COMPLETE', ->
              still_running = false

            while still_running
              yield @sleep 29*minutes
              uri = yield @cfg.recording_uri name
              @debug 'Recording next segment', @call.uuid, uri
              yield @cfg.api "uuid_record #{@call.uuid} start #{uri}"
              @notify event:'recording'
              yield @sleep 1*minutes
              @debug 'Stopping previous segment', @call.uuid, last_uri
              yield @cfg.api "uuid_record #{@call.uuid} stop #{last_uri}"
              last_uri = uri

            return

          keep_recording().catch (error) =>
            @debug "record_call: #{error.stack ? error}"

          @debug 'Going to record', name
          return true

      }

      return
