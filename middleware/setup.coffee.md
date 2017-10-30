    seem = require 'seem'
    nimble = require 'nimble-direction'
    pkg = require '../package.json'
    EventEmitter = require 'events'
    Moment = require 'moment-timezone'
    @name = "#{pkg.name}:middleware:setup"
    assert = require 'assert'
    FS = require 'esl'
    LRU = require 'lru-cache'

    Redis = require 'ioredis'
    RedisInterface = require 'normal-key/interface'

    Reference = require './reference'
    debug = (require 'tangible') @name

    seconds = 1000
    minutes = 60*seconds

    now = (tz = 'UTC') ->
      Moment().tz(tz).format()

    @config = seem ->
      yield nimble @cfg
      assert @cfg.prov?, 'Nimble did not inject cfg.prov'

    @server_pre = seem ->
      yield nimble @cfg
      assert @cfg.prov?, 'Nimble did not inject cfg.prov'

Local and Global Redis
----------------------

      make_a_redis = (label,config) =>
        a_redis = Redis.createClient config
        a_redis.on 'error', (error) =>
          debug "#{label}: #{error.command} #{error.args?.join(' ')}: #{error.stack ? error}"
        a_redis.on 'ready',         => debug "#{label}: ready"
        a_redis.on 'connect',       => debug "#{label}: connect"
        a_redis.on 'reconnecting',  => debug "#{label}: reconnecting"
        a_redis.on 'end',           => debug "#{label}: end"
        a_redis.on 'warning',       => debug "#{label}: warning"
        a_redis

      assert @cfg.redis?, 'cfg.redis (global redis) is required for Reference'

      @cfg.global_redis_client = make_a_redis 'global redis', @cfg.redis

      if @cfg.local_redis?
        @cfg.local_redis_client = make_a_redis 'local redis', @cfg.local_redis

How long should we keep a reference after the last update?

      call_timeout = 8*3600
      redis_interface = new RedisInterface @cfg.global_redis_client, call_timeout

      class HugePlayReference extends Reference
        interface: redis_interface

      @cfg.Reference = HugePlayReference

Period
------

Used by billing code.

      @cfg.period_of ?= (stamp = new Date(),timezone = 'UTC') ->
        Moment
        .tz stamp, timezone
        .format 'YYYY-MM'

Is-remote Cache
---------------

Use redis to retrieve the server on which this call should be hosted, and set it to `local_server` if none was previously set.
Returns either:
- `false` to indicate the call should be handled locally;
- the value previously stored if it is available;
- `null` if the determination could not be made (for example due to parameter, configuration, or server error).

If the `local_server` parameter is not provided (it normally should), only the previously stored value is checked. This should never be used when dealing with calls, since it means the call might not go through.

      is_remote_cache = LRU
        max: 2000
        maxAge: 1*minutes

      @cfg.is_remote = seem (name,local_server) =>

        unless name?
          return null

        key = "server for #{name}"

        unless @cfg.global_redis_client?
          debug.dev 'is_remote: Missing global redis'
          return null

Just probing (this is only useful when retrieving data, never when handling calls).

        if not local_server?
          server = is_remote_cache.get name
          if server is undefined
            server = yield @cfg.global_redis_client
              .get key
              .catch (error) ->
                debug.ops "error #{error.stack ? error}"
                null
            is_remote_cache.set name, server

          switch server?.substring 0, @cfg.host.length
            when null
              return null
            when @cfg.host
              return false
            else
              return server

Probe-and-update

        server = local_server

Set if not exists, [setnx](https://redis.io/commands/setnx)
(Note: there's also hsetnx/hget which could be used for this, not sure what's best practices.)

        first_time = yield @cfg.global_redis_client
          .setnx key, server
          .catch (error) ->
            debug.ops "error #{error.stack ? error}, forcing local server"
            1

        if not first_time
          server = yield @cfg.global_redis_client
            .get key
            .catch (error) ->
              debug.ops "error #{error.stack ? error}"
              null

Check whether handling is local (assuming FreeSwitch is co-hosted, which is our standard assumption).

        debug 'Checking for local handling', server, local_server

        switch server

          when null
            debug.ops 'Redis failed'
            return null

          when local_server
            debug 'Handling is local'
            return false

          else
            debug 'Handling is remote'
            return server

FreeSwitch API Client
---------------------

These methods parallel the ones in black-metal/api.
Eventually the two should be merged.

Create a new socket client

      _client = =>
        new Promise (resolve) =>
          try
            client = FS.client ->
              resolve this
            client.keepConnected (@cfg.socket_port ? 5722), '127.0.0.1'
          catch error
            debug '_client: error', error
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

      _api = seem (cmd) ->
        default_client ?= yield _client()
        res = yield default_client.bgapi cmd

* cfg.api(command) returns (a Promise for) the body of the response for a FreeSwitch `api` command.

      @cfg.api = seem (cmd) =>
        debug 'api', cmd
        res = yield _api cmd
        res?.body ? null

* cfg.api.send(command) returns (a Promise for) the `esl` response to the command.
* cfg.api.create() returns (a Promise for) an `esl` client.

      @cfg.api.send = _api
      @cfg.api.create = _client

* cfg.api.truthy(command) returns (a Promise for) a boolean indicating the success of the command.

      @cfg.api.truthy = (cmd) =>
        debug 'api.truthy', cmd
        on_success = (res) ->
          debug 'api.truthy', cmd, res
          switch
            when res.uuid?
              res.uuid
            when res.body is 'true'
              true
            when res.body is 'false'
              false
            when res.body[0] is '-'
              false
            else
              true
        on_failure = (error) ->
          debug 'api.truthy', cmd, error
          false

        _api cmd
        .then on_success, on_failure

      UNIQUE_ID = 'Unique-ID'
      EVENT_NAME = 'Event-Name'

FIXME: Can only be called once on a given `id`. Add e.g. Redis support to store monitored events counters & ids.

      monitor_client = null
      monitored_events = {}

Remember to always call `monitor.end()` when you are done with the monitor!

* cfg.api.monitor(unique_id,events) returns an EventEmitter that emits the requested events when they are triggered by FreeSwitch on the given Unique-ID. You MUST call `.end` once the EventEmitter is no longer needed.

      @cfg.api.monitor = seem (id,events) ->
        debug 'api.monitor: start', {id,events}
        monitor_client ?= yield _client()

Don't show the warning for 10 concurrent calls!
The number should really be an estimate of our maximum number of concurrent, monitored calls.

        monitor_client.setMaxListeners 200

        debug 'api.monitor: filtering', id
        yield monitor_client.filter UNIQUE_ID, id

        ev = new EventEmitter()

        listener = (msg) ->
          return unless msg?.body?
          msg_id = msg.body[UNIQUE_ID]
          msg_ev = msg.body[EVENT_NAME]
          if msg_id is id and msg_ev in events
            debug 'api.monitor received', msg_id, msg_ev
            ev?.emit msg_ev, msg

        for event in events
          yield do (event) ->
            monitor_client.on event, listener
            monitored_events[event] ?= 0
            if monitored_events[event]++ is 0
              debug 'Adding event json for', event
              monitor_client.event_json event

        ev.end = seem ->
          if not ev?
            debug 'api.monitor.end: called more than once (ignored)', {id,events}
            return

          debug 'api.monitor.end', {id,events}
          yield monitor_client.filter_delete UNIQUE_ID, id
          for event in events
            yield do (event) ->
              monitor_client.removeListener event, listener
              if --monitored_events[event] is 0
                debug 'api.monitor.end: nixevent', event
                monitor_client.nixevent event
          ev.removeAllListeners()
          ev = null
          debug 'api.monitor.end: done'

        debug 'api.monitor: ready', {id,events}

        ev

      return

Web
---

    @web = ->
      @cfg.versions[pkg.name] = pkg.version

Inbound notifications
---------------------

    @notify = ->

      @on_connexion = (init) =>

Run on re-connections (`welcome` is sent by spicy-action when we connect).

        @socket.on 'welcome', init

Run manually when we start (the `welcome` message has probably already been seen).

        init()

Register a new event on the bus.

      @register = (event,default_room = null) =>
        @on_connexion =>
          debug 'Register', {event, default_room}
          @socket.emit 'register', {event,default_room}

Configure our client to receive specific queues.

      @socket.on 'configured', (data) =>
        debug 'Socket configured', data

      @configure = (options) =>
        @on_connexion =>
          debug 'Configure', options
          @socket.emit 'configure', options

      @socket.on 'connect', =>
        debug.ops 'connect'
      @socket.on 'connect_error', =>
        debug.ops 'connect_error'
      @socket.on 'disconnect', =>
        debug.ops 'disconnect'

      return

Context Extension
-----------------

    @include = (ctx) ->

      _bus = new EventEmitter()

      ctx[k] = v for own k,v of {
        on: (ev,cb) -> _bus.on ev, cb
        once: (ev,cb) -> _bus.once ev, cb
        emit: (ev,data) -> _bus.emit ev, data

        statistics: @cfg.statistics

        sleep: (timeout) ->
          new Promise (resolve) ->
            setTimeout resolve, timeout

        direction: (direction) ->
          @session.direction = direction
          @emit 'direction', direction
          @report {event:'direction', direction}

`@_in()`: Build a list of target rooms for event reporting (as used by spicy-action).

        _in: seem (_in = [])->

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

          if @reference?
            tags = yield @reference.get_in().catch -> []
            for tag in tags
              push_in tag

          _in

Data reporting (e.g. to save for managers reports).
Typically `@report({state,…})` for calls state changes / progress, `@report({event,…})` for non-calls.
This version is meant to be used in-call.

        report: seem (report) ->
          unless @call? and @session?
            debug.dev 'report: improper environment'
            return false

          report.old_state ?= @session.state
          @session.state = report.state if report.state?

          report.timezone ?= @session.timezone
          report.timestamp ?= now report.timezone
          report.now = Date.now()
          report._in = yield @_in report._in
          report.host ?= @cfg.host
          report.type ?= 'report'

          report.source ?= @source
          report.destination ?= @destination
          report.direction ?= @session.direction
          report.dialplan ?= @session.dialplan
          report.country ?= @session.country
          report.number_domain ?= @session.number_domain
          report.number_domain_dialplan ?= @session.number_domain_data?.dialplan
          report.agent ?= @session.agent
          report.agent_name ?= @session.agent_name

          report.call = @call.uuid
          report.session = @session._id
          report.reference = @session.reference
          report.report_type = 'in-call'

          @cfg.statistics.emit 'report', report
          true

Real-time notification (e.g. to show on a web panel).

        notify: (report) ->
          report._notify = true
          @report report

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

          if @session.alternate_response?
            @session.alternate_response response
          else
            ctx.action 'respond', response

        sofia_string: seem (number, extra_params = []) ->

          debug 'sofia_string', number, extra_params

          id = "number:#{number}@#{@session.number_domain}"

          number_data = yield @cfg.prov
            .get id
            .catch (error) ->
              debug.ops "#{id} #{error.stack ? error}"
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

* hdr.X-En Endpoint name, set when dialing numbers.

          params = [
            extra_params...
            "sip_h_X-En=#{number_data.endpoint}"
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
          yield @reference.add_in @session.number._id
          yield @user_tags @session.number.tags
          if @session.number.timezone?
            @session.timezone ?= @session.number.timezone
          if @session.number.music?
            @session.music ?= @session.number.music

          if @session.number.error?
            @debug.dev "Could not locate destination number #{dst_number}"
            @notify state: 'invalid-local-number', number: @session.number._id
            yield @respond '486 Not Found'
            return

          @debug "validate_local_number: Got dst_number #{dst_number}", @session.number

          if @session.number.disabled
            @debug.ops "Number #{dst_number} is disabled"
            @notify state:'disabled-local-number', number: @session.number._id
            yield @respond '486 Administratively Forbidden' # was 403
            return

Set the endpoint name so that if we redirect to voicemail the voicemail module can locate the endpoint.

          @session.endpoint_name = @session.number.endpoint
          yield @reference.set_endpoint @session.number.endpoint
          yield @reference.add_in "endpoint:#{@session.number.endpoint}"

Set the account so that if we redirect to an external number the egress module can find it.

          yield @reference.set_account @session.number.account
          yield @reference.add_in "account:#{@session.number.account}"
          @report
            state: 'validated-local-number'
            number: @session.number._id
            endpoint: @session.endpoint_name
            account: @session.number.account

          dst_number

        global_redis: @cfg.global_redis_client
        local_redis: @cfg.local_redis_client

        tag: seem (tag) ->
          if tag?
            yield @reference.add_tag tag
            @report {event:'tag', tag}

        user_tag: seem (tag) ->
          if tag?
            yield @reference.add_tag "user-tag:#{tag}"
            @report {event:'user-tag', tag}

        user_tags: seem (tags) ->
          return unless tags?
          for tag in tags
            yield @user_tag tag

        has_tag: seem (tag) ->
          tag? and yield @reference.has_tag tag

        has_user_tag: seem (tag) ->
          tag? and yield @has_tag "user-tag:#{tag}"

        clear_call_center_tags: seem ->
          tags = yield @reference.tags()
          for tag in tags when tag is 'broadcast' or tag.match /^(skill|priority|queue):/
            yield @reference.del_tag tag
          null

        clear_user_tags: seem ->
          tags = yield @reference.tags()
          for tag in tags when tag.match /^user-tag:/
            yield @reference.del_tag tag
          null

        record_call: (name) ->
          unless @cfg.recording_uri?
            @debug.dev 'No recording_uri, call will not be recorded.'
            return false

Keep recording (async)

          keep_recording = seem =>
            @report event:'recording'
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
              @report event:'recording'
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
