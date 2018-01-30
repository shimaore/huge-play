    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:carrier:ingress:send"
    debug = (require 'tangible') @name

Send a call out using carrier-side rules.

    @include = seem ->

      return unless @session?.direction is 'ingress'

      @debug 'Ready'

      {ingress_target} = @session.profile_data

      @debug 'bridge',
        sip_profile: @session.sip_profile
        destination: @destination
        ingress_target: ingress_target

      res = yield @action 'bridge', "sofia/#{@session.sip_profile}/sip:#{@destination}@#{ingress_target}"

      data = res.body
      @session.bridge_data ?= []
      @session.bridge_data.push data
      @debug 'FreeSwitch response', res

      cause = data?.variable_last_bridge_hangup_cause ? data?.variable_originate_disposition
      @debug 'Cause', cause

      if cause in ['NORMAL_CALL_CLEARING', 'SUCCESS']
        @debug "Successful call when routing #{@destination} through #{ingress_target}"
      else
        @debug "Call failed: #{cause} when routing #{@destination} through #{ingress_target}"
