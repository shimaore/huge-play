    nimble = require 'nimble-direction'
    pkg = require '../package.json'
    {EventEmitter2} = require 'eventemitter2'
    Moment = require 'moment-timezone'
    @name = "#{pkg.name}:middleware:setup"
    assert = require 'assert'
    FS = require 'esl'
    LRU = require 'lru-cache'
    RedRingAxon = require 'red-rings-axon'
    BlueRing = require 'blue-rings'
    RedisInterface = require 'normal-key/interface'

    Redis = require 'ioredis'

    {RedisInterfaceReference,BlueRingReference} = require './reference'
    {debug,foot,heal} = (require 'tangible') @name

    seconds = 1000
    minutes = 60*seconds
    days = 24*60*minutes
    weeks = 7*days

    now = (tz = 'UTC') ->
      Moment().tz(tz).format()

    default_wrapper = null
    br = null

    @end = ->
      default_wrapper.end()
      br.end()
      @cfg.local_redis_client?.end()

    @config = ->
      await nimble @cfg
      assert @cfg.prov?, 'Nimble did not inject cfg.prov'

    @server_pre = ->

Red-Rings Axon connexion

* cfg.axon RedRingAxon configuration

      @cfg.rr = new RedRingAxon @cfg.axon ? {}

Prepare counters and registers

* cfg.blue_rings BlurRing (including Axon) configuration

      @cfg.blue_rings ?= {}
      @cfg.blue_rings.Value ?= BlueRing.integer_values
      @cfg.br = br = BlueRing.run @cfg.blue_rings

Seed initial values if provided

* cfg.blue_rings.seeds[] Initial values for blue-rings, including `.counter` or `.register`.

      {seeds} = @cfg.blue_rings
      for seed in seeds ? []
        switch
          when seed.counter?
            @cfg.br.setup_counter seed.name, seed.expire
            @cfg.br.update_counter seed.name, seed.counter
          when seed.register?
            @cfg.br.setup_text seed.name, seed.expire
            @cfg.br.update_text seed.name, seed.register

TBD: load from backup / database

      await nimble @cfg
      assert @cfg.prov?, 'Nimble did not inject cfg.prov'

Local Redis
-----------

      make_a_redis = (label,config) =>
        a_redis = Redis.createClient config
        a_redis.on 'error', (error) =>
          debug.error "#{label}: #{error.command} #{error.args?.join(' ')}", error
        a_redis.on 'ready',         => debug "#{label}: ready"
        a_redis.on 'connect',       => debug "#{label}: connect"
        a_redis.on 'reconnecting',  => debug "#{label}: reconnecting"
        a_redis.on 'end',           => debug "#{label}: end"
        a_redis.on 'warning',       => debug "#{label}: warning"
        a_redis

* @cfg.local_redis (Optional, recommended) If present, used as the configuration for a local redis server.

      if @cfg.local_redis?
        @cfg.local_redis_client = make_a_redis 'local redis', @cfg.local_redis

How long should we keep a reference after the last update?

      call_timeout = 8*3600

      if @cfg.use_bluerings_for_reference or not @cfg.local_redis_client?
        class HugePlayReference extends BlueRingReference
          interface: br
          timeout: call_timeout
      else
        redis_interface = new RedisInterface @cfg.local_redis_client, call_timeout
        class HugePlayReference extends RedisInterfaceReference
          interface: redis_interface
          timeout: call_timeout

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

Use blue-rings to retrieve the server on which this call should be hosted, and set it to `local_server` if none was previously set.
Returns either:
- `false` to indicate the call should be handled locally;
- the value previously stored if it is available;
- `null` if the determination could not be made (for example due to parameter, configuration, or server error).

If the `local_server` parameter is not provided (it normally should), only the previously stored value is checked. This should never be used when dealing with calls, since it means the call might not go through.

      @cfg.is_remote = (name,local_server) =>

        unless name?
          return null

        key = "server for #{name}"

        [coherent,server] = @cfg.br.get_text key

Just probing (this is only useful when retrieving data, never when handling calls).

        if not local_server?

          switch server?.substring 0, @cfg.host.length
            when null
              return null
            when @cfg.host
              return false
            else
              return server

Probe-and-update

        first_time = not server?

        if first_time
          @cfg.br.setup_text key, Date.now() + 1*minutes
          [coherent,server] = @cfg.br.update_text key, local_server, Date.now() + 2*weeks

Check whether handling is local (assuming FreeSwitch is co-hosted, which is our standard assumption).

        debug 'Checking for local handling', server, local_server

        switch server

          when null
            debug.ops 'Something failed'
            return null

          when local_server
            debug 'Handling is local'
            @cfg.br.update_text key, server, Date.now() + 1*weeks
            return false

          else
            debug 'Handling is remote'
            return server

FreeSwitch API Client
---------------------

These methods parallel the ones in black-metal/api.
Eventually the two should be merged.

Create a new socket client

      _wrapper = =>
        options =
          host: @cfg.socket_host ? '127.0.0.1'
          port: @cfg.socket_port ? 5722

        FS.createClient options

Use a default client for generic / shared APIs

      default_wrapper = await _wrapper()

      _api = (cmd) ->
        res = await default_wrapper.client.bgapi cmd

* cfg.api(command) returns (a Promise for) the body of the response for a FreeSwitch `api` command.

      @cfg.api = (cmd) =>
        debug 'api', cmd
        res = await _api cmd
        res?.body ? null

* cfg.api.send(command) returns (a Promise for) the `esl` response to the command.

      @cfg.api.send = _api

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

      return

Web
---

    @web = ->
      @cfg.versions[pkg.name] = pkg.version

Context Extension
-----------------

    @include = (ctx) ->

      _bus = new EventEmitter2()

      ctx.call.on 'error', (error) ->
        debug.dev 'Call Failure', error

      ctx[k] = v for own k,v of {
        on: (ev,cb) -> _bus.on ev, cb
        once: (ev,cb) -> _bus.once ev, cb
        emit: (ev,data) -> _bus.emit ev, data

        end: ->
          _bus.removeAllListeners()
          @call = null
          @session = null
          @reference = null
          return

        sleep: (timeout) ->
          new Promise (resolve) ->
            setTimeout resolve, timeout

        direction: (direction) ->
          @session?.direction = direction
          @emit 'direction', direction
          @report {event:'direction', direction}

Data reporting (e.g. to save for managers reports).
Typically `@report({state,…})` for calls state changes / progress, `@report({event,…})` for non-calls.
This version is meant to be used in-call.

        report: (report) ->
          unless @call? and @session? and @reference?
            debug.dev 'report: improper environment'
            return false

          report.old_state ?= @session.state
          @session.state = report.state if report.state?

          report.timezone ?= @session.timezone
          report.timestamp ?= now report.timezone
          report.now = Date.now()
          report.host ?= @cfg.host
          report.type ?= 'report'

          report.source ?= @source
          report.destination ?= @destination
          report.direction ?= @session.direction
          report.dialplan ?= @session.dialplan
          report.country ?= @session.country
          report.number_domain ?= @session.number_domain
          report.number_domain ?= await @reference.get_number_domain()
          report.number_domain_dialplan ?= @session.number_domain_data?.dialplan
          report.agent ?= @session.agent
          report.agent_name ?= @session.agent_name

          report.endpoint ?= @session.endpoint?.endpoint
          report.endpoint ?= @session.number?.endpoint
          report.endpoint ?= @session.endpoint_name

_This_ is highly ambiguous since it could be _any_ endpoint along the chaing of forwardings, transfers, etc.
We have no real way to know, though, and removing it (for example in middleware/client/ingress/pre) could lead to issues.

          report.endpoint ?= await @reference.get_endpoint()

          report.call = @call.uuid
          report.reference = @session.reference
          report.report_type = 'call'

          if report.agent?
            @cfg.rr.notify "agent:#{report.agent}", "call:#{report.call}", report
          if report.endpoint?
            @cfg.rr.notify "endpoint:#{report.endpoint}", "call:#{report.call}", report
          if report.number_domain?
            @cfg.rr.notify "number_domain:#{report.number_domain}", "call:#{report.call}", report
          true

Real-time notification (e.g. to show on a web panel).

        notify: (report) ->
          report._notify = true
          @report report

        set: (name,value) ->
          return unless name?

          if typeof name is 'string'
            await @res.set name, value
            return

          for own k,v of name
            await @res.set k, v

          return

        unset: (name) ->
          return unless name?

          if typeof name is 'string'
            await @res.set name, null
            return

          for k in name
            await @res.set k, null

          return

        export: (name,value) ->
          return unless name?

          if typeof name is 'string'
            await @res.export name, value
            return

          for own k,v of name
            await @res.export k, v

          return

        respond: (response) ->
          @notify state: 'immediate-response', response: response
          @session?.first_response_was ?= response

Prevent extraneous processing of this call.

          @direction 'responded'

          if @session?.alternate_response?
            @session?.alternate_response response
          else
            ctx.action 'respond', response

        sofia_string: (number, extra_params = []) ->

          debug 'sofia_string', number, extra_params

          id = "number:#{number}@#{@session.number_domain}"

          number_data = await @cfg.prov
            .get id
            .catch (error) ->
              debug.error id, error
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

        validate_local_number: ->

Retrieve number data.

* session.number (object) The record of the destination number interpreted as a local-number in `session.number_domain`.
* doc.local_number.disabled (boolean) If true the record is not used.

          dst_number = "#{@destination}@#{@session.number_domain}"
          @session.number = await @cfg.prov
            .get "number:#{dst_number}"
            .catch (error) -> {disabled:true,error}
          await @user_tags @session.number.tags
          if @session.number.timezone?
            @session.timezone ?= @session.number.timezone
          if @session.number.music?
            @session.music ?= @session.number.music

          if @session.number.error?
            debug.dev "Could not locate destination number #{dst_number}"
            @notify state: 'invalid-local-number', number: @session.number._id
            await @respond '486 Not Found'
            return

          debug "validate_local_number: Got dst_number #{dst_number}", @session.number

          if @session.number.disabled
            debug.ops "Number #{dst_number} is disabled"
            @notify state:'disabled-local-number', number: @session.number._id
            await @respond '486 Administratively Forbidden' # was 403
            return

Set the endpoint name so that if we redirect to voicemail the voicemail module can locate the endpoint.

          @session.endpoint_name = @session.number.endpoint
          await @reference.set_endpoint @session.number.endpoint

Set the account so that if we redirect to an external number the egress module can find it.

          await @reference.set_account @session.number.account
          @report
            state: 'validated-local-number'
            number: @session.number._id
            endpoint: @session.endpoint_name
            account: @session.number.account

          dst_number

        local_redis: @cfg.local_redis_client

User tags

        user_tag: (tag) ->
          unless @reference?
            debug.dev 'user_tag: missing @reference', tag
            return
          if tag?
            await @reference.add_ 'user-tag', tag
            heal @report {event:'user-tag', tag}
          return

        user_tags: (tags) ->
          return unless tags?
          for tag in tags
            await @user_tag tag
          return

        has_user_tag: (tag) ->
          unless @reference?
            debug.dev 'has_user_tag: missing @reference', tag
            return false
          tag? and await @reference.has_ 'user-tag', tag

        clear_user_tags: ->
          unless @reference?
            debug.dev 'clear_user_tags: missing @reference'
            return
          await @reference.clear_ 'user-tag'
          return

Record call

        record_call: (name,metadata = {}) ->
          unless @cfg.recording_uri?
            debug.dev 'No recording_uri, call will not be recorded.'
            return false

          Object.assign metadata,
            name: name
            number_domain: @session?.number_domain
            number: @session?.number?._id
            agent: @session?.agent
            timezone: @session?.timezone
            groups: @session?.number?.allowed_groups
            source: @source
            destination: @destination
            call_start: new Date().toJSON()
            recording_start: new Date().toJSON()
            reference: @session?.reference

Keep recording (async)

          keep_recording = =>
            {uuid} = @call
            uri = await @cfg.recording_uri name, metadata
            debug 'Recording', uuid, uri
            outcome = await @cfg.api "uuid_record #{uuid} start #{uri}"
            @report Object.assign {event:'recording', uri}, metadata
            debug 'Recording', uuid, uri, outcome

            last_uri = uri

            while @cfg.api.truthy "uuid_exists #{uuid}"
              await @sleep 29*minutes

              if @cfg.api.truthy "uuid_exists #{uuid}"
                metadata.recording_start = new Date().toJSON()
                uri = await @cfg.recording_uri name, metadata
                debug 'Recording next segment', uuid, uri
                await @cfg.api "uuid_record #{uuid} start #{uri}"
                @report Object.assign {event:'recording', uri}, metadata

              await @sleep 1*minutes
              debug 'Stopping previous segment', uuid, last_uri
              await @cfg.api "uuid_record #{uuid} stop #{last_uri}"
              last_uri = uri

            return

          heal 'record_call', keep_recording()

          debug 'Going to record', name
          return true

      }

      return
