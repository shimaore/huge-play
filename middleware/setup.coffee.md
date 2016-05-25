    seem = require 'seem'
    nimble = require 'nimble-direction'
    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:setup"
    debug = (require 'debug') @name
    assert = require 'assert'

    @web = ->
      @cfg.versions[pkg.name] = pkg.version

    @config = seem ->
      yield nimble @cfg
      assert @cfg.prov?, 'Nimble did not inject cfg.prov'

    @server_pre = seem ->
      yield nimble @cfg
      assert @cfg.prov?, 'Nimble did not inject cfg.prov'

    @include = (ctx) ->

      ctx[k] = v for own k,v of {
        statistics: @cfg.statistics

`@_in()`: Build a list of target rooms for event reporting (as used by spicy-action).

        _in: ->

Add any endpoint- or number- specific dispatch room (this allows end-users to receive events for endpoints and numbers they are authorized to monitor).

          _in = []
          push_in = (room) ->
            return if not room? or room in _in
            _in.push room

We assume the room names match record IDs.

          push_in @session.endpoint?._id
          push_in ['endpoint',@session.number?.endpoint].join ':'
          push_in @session.number?._id
          push_in @session.e164_number?._id

          _in

        report: (o) ->
          unless @call? and @session? and @statistics?
            debug 'report: improper environment'
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

        set: seem (name,value) ->
          return unless name?
          if typeof name is 'string'
            if value is null
              ctx.action 'unset', name
            else
              ctx.action 'set', "#{name}=#{value}"
          else
            yield ctx.set k,v for own k,v of name

        unset: seem (name) ->
          return unless name?
          if typeof name is 'string'
              ctx.action 'unset', name
          else
            yield ctx.unset k for k in name

        export: seem (name,value) ->
          return unless name?
          if typeof name is 'string'
            if value is null
              ctx.action 'export', name
            else
              ctx.action 'export', "#{name}=#{value}"
          else
            yield ctx.export k,v for own k,v of name

        respond: (response) ->
          @statistics?.add ['immediate-response',response]
          @report state: 'immediate-response', response: response
          @session.first_response_was ?= response

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
              debug "#{id} #{error.stack ? error}"
              {}

          return '' unless number_data.number?

This is a simplified version of the sofia-string building code found in middleware:client:ingress:send.

          destination = number_data.number.split('@')[0]
          target = number_data.endpoint_via ? @cfg.ingress_target
          uri = "sip:#{destination}@#{target}"
          sofia = "sofia/#{@session.sip_profile}/#{uri}"

* hdr.X-CCNQ3-Endpoint Endpoint name, set when dialing numbers.
* hdr.X-CCNQ3-Number-Domain Number domain name, set when dialing numbers.

          params = [
            extra_params...
            "sip_h_X-CCNQ3-Endpoint=#{number_data.endpoint}"
            "sip_h_X-CCNQ3-Number-Domain=#{@session.number_domain}"
          ]

          "[#{params.join ','}]#{sofia}"

        validate_local_number: seem ->

Retrieve number data.

* session.number (object) The record of the destination number interpreted as a local-number in `session.number_domain`.
* doc.local_number.disabled (boolean) If true the record is not used.

          dst_number = "#{@destination}@#{@session.number_domain}"
          @session.number = yield @cfg.prov.get("number:#{dst_number}").catch (error) -> {disabled:true,error}

          if @session.number.error?
            debug "Could not locate destination number #{dst_number}: #{@session.number.error}"
            return @respond '486 Not Found'

          debug "Got dst_number #{dst_number}", @session.number

          if @session.number.disabled
            debug "Number #{dst_number} is disabled"
            return @respond '486 Administratively Forbidden' # was 403

Set the endpoint name so that if we redirect to voicemail the voicemail module can locate the endpoint.

          @session.endpoint_name = @session.number.endpoint

          dst_number

      }

      return
