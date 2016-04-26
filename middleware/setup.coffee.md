    seem = require 'seem'
    nimble = require 'nimble-direction'
    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:setup"
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
          ctx.action 'respond', response

        sofia_string: seem (number, extra_params = []) ->

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
      }

      return
