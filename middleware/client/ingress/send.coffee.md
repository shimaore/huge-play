    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:send"
    debug = (require 'debug') @name

    @include = seem ->

      return unless @session.direction is 'ingress'

      debug 'Ready',
        sip_profile: @session.sip_profile
        ingress_target: @cfg.ingress_target

TODO: use gateways. set `ping` on the sip_profile, and dial using sofia/gateway/primary/sip:...|sofia/gateway/secondary/sip:...
And I believe we need to use `[let_timeout=4]` or something like this to handle failover properly. (Or maybe not, maybe this is handled directly by sofia-sip using the Tx timers, since I don't think that 100 is brought back up to FreeSwitch, so FreeSwitch probably doesn't have a say in it.)

      bridge = [@cfg.ingress_target]

      sofia = bridge.map (e) => "sofia/#{@session.sip_profile}/sip:#{@destination}@#{e}"

      yield @set
        continue_on_fail: true

      debug 'Bridging', {bridge,sofia}

      res = yield @action 'bridge', sofia.join ','
      data = res.body
      debug 'FreeSwitch response', res

      cause = data?.variable_last_bridge_hangup_cause ? data?.variable_originate_disposition
      debug 'Cause', cause

      if cause in ['NORMAL_CALL_CLEARING', 'SUCCESS']
        debug "Successful call when routing #{@destination} through #{bridge.join ','}"
      else
        debug "Call failed: #{cause} when routing #{@destination} through #{bridge.join ','}"
        @respond '486 Call Failed'
