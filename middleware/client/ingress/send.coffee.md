    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:send"

    @include = ->

      return unless @session.direction is 'ingress'

      @debug 'Ready'

* session.initial_destinations (array) On ingress, client-side calls, list of target routes for `mod_sofia`, each route consisting of an object containing a `to_uri` URI (to be used with the standard SIP profile defined in session.sip_profile ) and an optional `parameters` array of per-leg parameter strings.

There might no `initial_destinations` if the call was rejected in ornaments, reject-anonymous, etc.

      if @session.initial_destinations?.length > 0
        send.call this, @session.initial_destinations

send
====

Send call to (OpenSIPS or other) with processing for CFDA, CFNR, CFB.

    @send = send = seem (destinations) ->

      sofia = destinations.map ({ parameters = [], to_uri }) =>
        "[#{parameters.join ','}]sofia/#{@session.sip_profile}/#{to_uri}"

      @debug 'send', sofia

Send the call(s)
----------------

      yield @set
        continue_on_fail: true

      @debug 'Bridging', sofia

      res = yield @action 'bridge', sofia.join ','

Post-attempt handling
---------------------

      data = res.body
      @session.bridge_data ?= []
      @session.bridge_data.push data
      @debug 'FreeSwitch response', res

Retrieve the FreeSwitch Cause Code description, and the SIP error code.

### last bridge hangup cause

For example: `NORMAL_CLEARING` (answer+bridge), `NORMAL_CALL_CLEARING` (bridge, call is over)

      cause = data?.variable_last_bridge_hangup_cause

Note: there is also `variable_bridge_hangup_cause`

### originate disposition

For example: `SUCCESS`, `ORIGINATOR_CANCEL`.

      cause ?= data?.variable_originate_disposition

Note: also `variable_endpoint_disposition` (`ANSWER`), `variable_DIALSTATUS` (`SUCCESS`)

### last bridge proto-specific hangup cause

For example: `sip:200` → `200`

      code = data?.variable_last_bridge_proto_specific_hangup_cause?.match(/^sip:(\d+)$/)?[1]

### sip term status

For example: `200`

      code ?= data?.variable_sip_term_status

      @debug 'Outcome', {cause,code}

### For transfers, we also get state information.

- `variable_transfer_disposition: 'replaced'`
- `variable_endpoint_disposition: 'ATTENDED_TRANSFER'`

      @session.was_connected = cause in ['NORMAL_CALL_CLEARING', 'NORMAL_CLEARING', 'SUCCESS']
      @session.was_transferred = data.variable_transfer_history?
      @session.was_picked = cause in ['PICKED_OFF']

Success
-------

No further processing in case of success.

      if @session.was_connected
        @debug "Successful call when routing #{@destination} through #{sofia.join ','}"
        @session.reference_data.call_state.push 'answered'
        return

      if @session.was_picked
        @debug "Picked call when routing #{@destination} through #{sofia.join ','}"
        @session.reference_data.call_state.push 'picked'
        return

      if @session.was_transferred
        @debug "Transferred call when routing #{@destination} through #{sofia.join ','}"
        @session.reference_data.call_state.push 'transferred'
        return

Note: we do not hangup since some centrex scenarios might want to do post-call processing (survey, ...).

Not Registered
--------------

OpenSIPS marker for not registered

      if code is '604'
        yield @debug.csr 'not-registered',
          destination: @destination
          enpoint: @session.endpoint_name
          tried_cfnr: @session.tried_cfnr

      if code is '604' and not @session.tried_cfnr
        @session.reason = 'unavailable' # RFC5806
        if @session.cfnr_voicemail
          @debug 'cfnr:voicemail'
          @destination = @session.cfnr_voicemail_number
          @direction 'voicemail'
          return
        if @session.cfnr_number?
          @debug 'cfnr:forward'
          @session.destination = @session.cfnr_number
          @direction 'forward'
          return
        if @session.cfnr?
          @debug 'cfnr:fallback'
          @session.tried_cfnr = true
          return send.call this, [ to_uri: @session.cfnr ]

Try static routing on 604 without CFNR (or CFNR already attempted)

      if code is '604'
        unless @session.fallback_destinations?
          @debug 'cfnr: no fallback'
          return @respond '500 No Fallback'
        if @session.tried_fallback
          @debug 'cfnr: already attempted fallback'
          return @respond '500 Fallback Failed'

        @debug 'cfnr: fallback on 604'
        @session.tried_fallback = true
        return send.call this, @session.fallback_destinations

Busy
----

      if code is '486' and not @session.tried_cfb
        @session.reason = 'user-busy' # RFC5806
        if @session.cfb_voicemail
          @debug 'cfb: voicemail'
          @destination = @session.cfb_voicemail_number
          @direction 'voicemail'
          return
        if @session.cfb_number?
          @debug 'cfb:number'
          @session.destination = @session.cfb_number
          @direction 'forward'
          return
        if @session.cfb?
          @debug 'cfb: fallback'
          @session.tried_cfb = true
          return send.call this, [ to_uri: @session.cfb ]

All other codes
---------------

      @debug "Call failed: #{cause}/#{code} when routing #{@destination} through #{sofia.join ','}"

Use CFDA if present

      if not @session.tried_cfda
        @session.reason = 'no-answer' # RFC5806
        if @session.cfda_voicemail
          @debug 'cfda: voicemail'
          @destination = @session.cfda_voicemail_number
          @direction 'voicemail'
          return
        if @session.cfda_number?
          @debug 'cfda:number'
          @session.destination = @session.cfda_number
          @direction 'forward'
          return
        if @session.cfda?
          @debug 'cfda: fallback'
          @session.tried_cfda = true
          return send.call this, [ to_uri: @session.cfda ]

      @debug 'Call Failed'
      @session.call_failed = true
      return
