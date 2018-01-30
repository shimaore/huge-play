    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:carrier:egress:send"
    debug = (require 'tangible') @name

Send a call out using carrier-side rules.

    @include = seem ->

      return unless @session?.direction is 'egress'

      @debug 'Ready'

      {egress_target} = @session.profile_data

      @debug 'bridge',
        sip_profile: @session.sip_profile
        destination: @destination
        egress_target: egress_target

      res = yield @action 'bridge', "sofia/#{@session.sip_profile}/sip:#{@destination}@#{egress_target}"

      data = res.body
      @session.bridge_data ?= []
      @session.bridge_data.push data
      @debug 'FreeSwitch response', res

      cause = data?.variable_last_bridge_hangup_cause ? data?.variable_originate_disposition
      @debug 'Cause', cause

      if cause in ['NORMAL_CALL_CLEARING', 'SUCCESS']
        @debug "Successful call when routing #{@destination} through #{egress_target}"
      else
        @debug "Call failed: #{cause} when routing #{@destination} through #{egress_target}"
