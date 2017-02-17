    seem = require 'seem'
    nimble = require 'nimble-direction'
    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:setup"
    assert = require 'assert'

    Redis = require 'redis'
    Bluebird = require 'bluebird'
    Bluebird.promisifyAll Redis.RedisClient.prototype
    Bluebird.promisifyAll Redis.Multi.prototype

    @config = seem ->
      yield nimble @cfg
      assert @cfg.prov?, 'Nimble did not inject cfg.prov'

    @server_pre = seem ->
      yield nimble @cfg
      assert @cfg.prov?, 'Nimble did not inject cfg.prov'

      if @cfg.redis?
        @cfg.redis_client = redis = Redis.createClient @cfg.redis
        redis?.on 'error', (error) =>
          @debug "redis: #{error.command} #{error.args?.join(' ')}: #{error.stack ? error}"
        redis.on 'ready', => @debug "redis: ready"
        redis.on 'connect', => @debug "redis: connect"
        redis.on 'reconnecting', => @debug "redis: reconnecting"
        redis.on 'end', => @debug "redis: end"
        redis.on 'warning', => @debug "redis: warning"

    @web = ->
      @cfg.versions[pkg.name] = pkg.version

    @notify = ->

      @cfg.statistics.on 'reference', (data) =>
        @socket.emit 'reference', data

      @cfg.statistics.on 'call', (data) =>
        @socket.emit 'call',
          host: @cfg.host
          data: data

    @include = (ctx) ->

      ctx[k] = v for own k,v of {
        statistics: @cfg.statistics

        direction: (direction) ->
          @session.direction = direction
          @call.emit 'direction', direction

`@_in()`: Build a list of target rooms for event reporting (as used by spicy-action).

        _in: (_in = [])->

Add any endpoint- or number- specific dispatch room (this allows end-users to receive events for endpoints and numbers they are authorized to monitor).

          push_in = (room) ->
            return if not room? or room in _in
            _in.push room

We assume the room names match record IDs.

          push_in @session.endpoint?._id
          push_in ['endpoint',@session.number?.endpoint].join ':'
          push_in @session.number?._id
          push_in @session.e164_number?._id

          _in

Notice that `report` only works if e.g. tough-rate/middleware/call-handler sends the notification out via socket.io.
FIXME: Move the `call` socket.io code from tough-rate to huge-play.

        report: (o) ->
          unless @call? and @session?
            @debug.dev 'report: improper environment'
            return

          o.call ?= @call.uuid
          o.source ?= @source
          o.destination ?= @destination
          o.direction ?= @session.direction
          o.dialplan ?= @session.dialplan
          o.country ?= @session.country
          o.number_domain ?= @session.number_domain
          o._in ?= @_in()
          @statistics?.emit 'call', o

        save_ref: seem ->
          data = @session.reference_data
          @statistics?.emit 'reference', data
          if @cfg.update_session_reference_data?
            yield @cfg.update_session_reference_data data
          else
            @debug.dev 'Missing @cfg.update_session_reference_data, not saving'

        get_ref: seem ->
          if @cfg.get_session_reference_data?
            @debug 'Loading reference_data', @session.reference
            @session.reference_data ?= yield @cfg.get_session_reference_data @session.reference
          else
            @debug.csr 'Missing @cfg.get_session_reference_data, using empty reference_data', @session.reference
            @session.reference_data ?= {}

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
          @report state: 'immediate-response', response: response
          @session.first_response_was ?= response

Prevent extraneous processing of this call.

          @direction 'responded'

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

          if @session.number.error?
            @debug "Could not locate destination number #{dst_number}: #{@session.number.error}"
            yield @respond '486 Not Found'
            return

          @debug "validate_local_number: Got dst_number #{dst_number}", @session.number

          if @session.number.disabled
            @debug "Number #{dst_number} is disabled"
            yield @respond '486 Administratively Forbidden' # was 403
            return

Set the endpoint name so that if we redirect to voicemail the voicemail module can locate the endpoint.

          @session.endpoint_name = @session.number.endpoint

Set the account so that if we redirect to an external number the egress module can find it.

          @session.reference_data.account = @session.number.account
          yield @save_ref()

          dst_number

        redis: @cfg.redis_client

        is_remote: seem (name,local_server) ->

          unless @redis?
            @debug.dev 'Missing redis'
            return null

Use redis to retrieve the server on which this call should be hosted.

          server = local_server

Set if not exists, [setnx](https://redis.io/commands/setnx)
(Note: there's also hsetnx/hget which could be used for this, not sure what's best practices.)

          key = "server for #{name}"

          first_time = yield @redis
            .setnxAsync key, server
            .catch (error) ->
              @debug.ops "error #{error.stack ? error}"
              null

          if not first_time
            server = yield @redis
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

      }

      return
