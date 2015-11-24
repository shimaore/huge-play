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
        hangup_after_bridge: false

      debug 'Bridging', {sofia}

      res = yield @action 'bridge', sofia.join ','

Post-attempt handling
---------------------

      data = res.body
      debug 'FreeSwitch response', res

Retrieve the FreeSwitch Cause Code description, and the SIP error code.

### last bridge hangup cause

For example: `NORMAL_CLEARING` (answer+bridge), `NORMAL_CALL_CLEARING` (bridge, call is over)

      cause = data?.variable_last_bridge_hangup_cause

Note: there is also `variable_bridge_hangup_cause`

### originate disposition

For example: `SUCCESS`

      cause ?= data?.variable_originate_disposition

Note: also `variable_endpoint_disposition` (`ANSWER`), `variable_DIALSTATUS` (`SUCCESS`)

### last bridge proto-specific hangup cause

For example: `sip:200` → `200`

      code = data?.variable_last_bridge_proto_specific_hangup_cause?.match(/^sip:(\d+)$/)?[1]

### sip term status

For example: `200`

      code ?= data?.variable_sip_term_status

      debug 'Outcome', {cause,code}

Success
-------

No further processing in case of success.

      if cause in ['NORMAL_CALL_CLEARING', 'SUCCESS', 'NORMAL_CLEARING']
        debug "Successful call when routing #{@destination} through #{sofia.join ','}"
        return

Note: we do not hangup since some centrex scenarios might want to do post-call processing (survey, ...).

Not Registered
--------------

OpenSIPS marker for not registered

      if code is '604' and not @session.tried_cfnr
        @session.reason = 'unavailable' # RFC5806
        if @session.cfnr_voicemail
          debug 'cfnr:voicemail'
          @session.direction = 'voicemail'
          return
        if @session.cfnr_number?
          debug 'cfnr:forward'
          @session.direction = 'forward'
          @session.destination = @session.cfnr_number
          return
        if @session.cfnr?
          debug 'cfnr:fallback'
          @session.tried_cfnr = true
          @session.uris = [@session.cfnr]
          return send.call this

Try static routing on 604 without CFNR (or CFNR already attempted)

      if code is '604'
        endpoint = @session.endpoint
        if not endpoint?
          debug 'cfnr: no endpoint to fall back to'
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
        debug 'cfnr: fallback to endpoint'
        return send.call this

Busy
----

      if code is '486' and not @session.tried_cfb
        @session.reason = 'user-busy' # RFC5806
        if @session.cfb_voicemail
          debug 'cfb: voicemail'
          @session.direction = 'voicemail'
          return
        if @session.cfb_number?
          debug 'cfb:number'
          @session.direction = 'forward'
          @session.destination = @session.cfb_number
          return
        if @session.cfb?
          debug 'cfb: fallback'
          @session.tried_cfb = true
          @session.uris = [@session.cfb]
          return send.call this

All other codes
---------------

      debug "Call failed: #{cause}/#{code} when routing #{@destination} through #{sofia.join ','}"

Use CFDA if present

      if not @session.tried_cfda
        @session.reason = 'no-answer' # RFC5806
        if @session.cfda_voicemail
          debug 'cfda: voicemail'
          @session.direction = 'voicemail'
          return
        if @session.cfda_number?
          debug 'cfda:number'
          @session.direction = 'forward'
          @session.destination = @session.cfda_number
          return
        if @session.cfda?
          debug 'cfda: fallback'
          @session.tried_cfda = true
          @session.uris = [@session.cfda]
          return send.call this

      debug 'Call Failed'
      @session.call_failed = true
      return
