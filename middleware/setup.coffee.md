    nimble = require 'nimble-direction'
    pkg = require '../package.json'
    {EventEmitter2} = require 'eventemitter2'
    Moment = require 'moment-timezone'
    @name = "#{pkg.name}:middleware:setup"
    assert = require 'assert'
    FS = require 'esl'
    LRU = require 'lru-cache'
    RedRingAxon = require 'red-rings-axon'

    Redis = require 'ioredis'
    RedisInterface = require 'normal-key/interface'

    Reference = require './reference'
    {debug,foot} = (require 'tangible') @name

    seconds = 1000
    minutes = 60*seconds

    now = (tz = 'UTC') ->
      Moment().tz(tz).format()

    default_wrapper = null

    @end = ->
      default_wrapper.end()
      @cfg.global_redis_client.end()
      if @cfg.local_redis_client isnt @cfg.global_redis_client
        @cfg.local_redis_client.end()

    @config = ->
      await nimble @cfg
      assert @cfg.prov?, 'Nimble did not inject cfg.prov'

    @server_pre = ->

Red-Rings Axon connexion

      @cfg.rr = new RedRingAxon @cfg.axon ? {}

      await nimble @cfg
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

* @cfg.redis (Required) Configuration for a global redis server shared by all instances.

      @cfg.global_redis_client = make_a_redis 'global redis', @cfg.redis

* @cfg.local_redis (Optional, recommended) If present, used as the configuration for a local redis server. Default: use the global redis server defined in @cfg.redis

      if @cfg.local_redis?
        @cfg.local_redis_client = make_a_redis 'local redis', @cfg.local_redis
      else
        @cfg.local_redis_client = @cfg.global_redis_client

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

      @cfg.is_remote = (name,local_server) =>

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
            server = await @cfg.global_redis_client
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

        first_time = await @cfg.global_redis_client
          .setnx key, server
          .catch (error) ->
            debug.ops "error #{error.stack ? error}, forcing local server"
            1

        if not first_time
          server = await @cfg.global_redis_client
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

        statistics: @cfg.statistics

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
          unless @call? and @session?
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

          @cfg.statistics.emit 'report', report

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
          @statistics?.add ['immediate-response',response]
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
            @debug.dev "Could not locate destination number #{dst_number}"
            @notify state: 'invalid-local-number', number: @session.number._id
            await @respond '486 Not Found'
            return

          @debug "validate_local_number: Got dst_number #{dst_number}", @session.number

          if @session.number.disabled
            @debug.ops "Number #{dst_number} is disabled"
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

        global_redis: @cfg.global_redis_client
        local_redis: @cfg.local_redis_client

        tag: (tag) ->
          if tag?
            await @reference.add_tag tag
            @report {event:'tag', tag}

        user_tag: (tag) ->
          if tag?
            await @reference.add_tag "user-tag:#{tag}"
            @report {event:'user-tag', tag}

        user_tags: (tags) ->
          return unless tags?
          for tag in tags
            await @user_tag tag

        has_tag: (tag) ->
          tag? and await @reference.has_tag tag

        has_user_tag: (tag) ->
          tag? and await @has_tag "user-tag:#{tag}"

        clear_call_center_tags: ->
          tags = await @reference.tags()
          for tag in tags when tag is 'broadcast' or tag.match /^(skill|priority|queue):/
            await @reference.del_tag tag
          null

        clear_user_tags: ->
          tags = await @reference.tags()
          for tag in tags when tag.match /^user-tag:/
            await @reference.del_tag tag
          null

        record_call: (name,metadata = {}) ->
          unless @cfg.recording_uri?
            @debug.dev 'No recording_uri, call will not be recorded.'
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

Keep recording (async)

          keep_recording = =>
            {uuid} = @call
            uri = await @cfg.recording_uri name, metadata
            @debug 'Recording', uuid, uri
            outcome = await @cfg.api "uuid_record #{uuid} start #{uri}"
            @report Object.assign {event:'recording', uri}, metadata
            @debug 'Recording', uuid, uri, outcome

            last_uri = uri

            still_running = true
            @call.once 'CHANNEL_HANGUP_COMPLETE', ->
              still_running = false

            while still_running
              await @sleep 29*minutes

              if still_running
                metadata.recording_start = new Date().toJSON()
                uri = await @cfg.recording_uri name, metadata
                @debug 'Recording next segment', uuid, uri
                await @cfg.api "uuid_record #{uuid} start #{uri}"
                @report Object.assign {event:'recording', uri}, metadata

              await @sleep 1*minutes
              @debug 'Stopping previous segment', uuid, last_uri
              await @cfg.api "uuid_record #{uuid} stop #{last_uri}"
              last_uri = uri

            return

          keep_recording().catch (error) =>
            @debug "record_call: #{error.stack ? error}"

          @debug 'Going to record', name
          return true

      }

      return
