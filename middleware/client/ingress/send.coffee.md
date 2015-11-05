    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:send"
    debug = (require 'debug') @name

    @include = ->

      return unless @session.direction is 'ingress'

      debug 'Ready'

      send.call this

send
====

Send call to (OpenSIPS or other) with processing for CFDA, CFNR, CFB.

    @send = send = seem ->

TODO: use gateways. set `ping` on the sip_profile, and dial using sofia/gateway/primary/sip:...|sofia/gateway/secondary/sip:...
And I believe we need to use `[let_timeout=4]` or something like this to handle failover properly. (Or maybe not, maybe this is handled directly by sofia-sip using the Tx timers, since I don't think that 100 is brought back up to FreeSwitch, so FreeSwitch probably doesn't have a say in it.)

`session.targets` might be a list of target domains (to be used with the current destination number)

      targets = @session.targets ? [@cfg.ingress_target]

`session.uris` might be a list of target URIs (to be used with the standard SIP profile)

      uris = @session.uris ? targets.map (e) => "sip:#{@destination}@#{e}"

`session.sofia_parameters` are optional (dialstring-global) parameters for sofia.

      parameters = @session.sofia_parameters ? ''

`session.sofia` might be a complete `bridge` command parameter set

      sofia = @session.sofia ? uris.map (e) => "{#{parameters}}sofia/#{@session.sip_profile}/#{e}"

      debug 'send', sofia

Clear fields so that we can safely retry.

      @session.targets = null
      @session.uris = null
      @session.sofia_parameters = null
      @session.sofia = null

Send the call(s)
----------------

      yield @set
        continue_on_fail: true

      debug 'Bridging', {sofia}

      res = yield @action 'bridge', sofia.join ','

Post-attempt handling
---------------------

      data = res.body
      debug 'FreeSwitch response', res

Retrieve the FreeSwitch Cause Code description, and the SIP error code.

      cause = data?.variable_last_bridge_hangup_cause ? data?.variable_originate_disposition
      code = data?.variable_sip_term_status
      debug 'Outcome', {cause,code}

No further processing in case of success.

      if cause in ['NORMAL_CALL_CLEARING', 'SUCCESS']
        debug "Successful call when routing #{@destination} through #{sofia.join ','}"
        return

OpenSIPS marker for not registered

      if code is '604'
        if not @session.tried_cfnr and cfnr = @session.number.cfnr
          @session.tried_cfnr = true
          @session.uris = [cfnr]
          return send.call this

Try static routing on 604 without CFNR (or CFNR already attempted)

        else
          endpoint = @session.endpoint
          if not endpoint?
            return @respond '500 Endpoint Error'

          domain = endpoint?.user_srv ? endpoint?.user_ip

This will set the RURI and the To field. Notice that the RURI is actually `sip_invite_req_uri`, while the To field is `sofia/.../<To-field>`

          @session.targets = [domain]

Alternatives for routing:
- `sip_invite_req_uri`
- `sip_route_uri`
- `sip_network_destination`
- `;fs_path=`

          @session.parameters =
            sip_network_destination: endpoint.endpoint
          return send.call this

Busy

      if code is '486' and not @session.tried_cfb and cfb = @session.number.cfb
        @session.tried_cfb = true
        @session.uris = [cfb]
        return send.call this

All other codes

      debug "Call failed: #{cause}/#{code} when routing #{@destination} through #{sofia.join ','}"

Use CFDA if present

      if not @session.tried_cfda and cfda = @session.number.cfda
        @session.tried_cfda = true
        @session.uris = [cfda]
        return send.call this

      @respond '486 Call Failed'
