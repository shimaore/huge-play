    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:send"
    debug = (require 'debug') @name
    cuddly = (require 'cuddly') @name

    @include = ->

      return unless @session.direction is 'ingress'

      debug 'Ready'

* session.initial_destinations (array) On ingress, client-side calls, list of target routes for `mod_sofia`, each route consisting of an object containing a `to_uri` URI (to be used with the standard SIP profile defined in session.sip_profile ) and an optional `parameters` array of per-leg parameter strings.

      send.call this, @session.initial_destinations

send
====

Send call to (OpenSIPS or other) with processing for CFDA, CFNR, CFB.

    @send = send = seem (destinations) ->

      sofia = destinations.map ({ parameters = [], to_uri }) =>
        "[#{parameters.join ','}]sofia/#{@session.sip_profile}/#{to_uri}"

      debug 'send', sofia

Send the call(s)
----------------

      yield @set
        continue_on_fail: true
        hangup_after_bridge: false

      debug 'Bridging', sofia

      res = yield @action 'bridge', sofia.join ','

Post-attempt handling
---------------------

      data = res.body
      @session.bridge_data ?= []
      @session.bridge_data.push data
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
        @session.reference_data.call_state = 'success'
        return

Note: we do not hangup since some centrex scenarios might want to do post-call processing (survey, ...).

Not Registered
--------------

OpenSIPS marker for not registered

      if code is '604'
        yield cuddly.csr 'not-registered',
          destination: @destination
          enpoint: @session.endpoint_name
          tried_cfnr: @session.tried_cfnr

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
          return send.call this, [ to_uri: @session.cfnr ]

Try static routing on 604 without CFNR (or CFNR already attempted)

      if code is '604'
        unless @session.fallback_destinations?
          debug 'cfnr: no fallback'
          return @respond '500 No Fallback'
        if @session.tried_fallback
          debug 'cfnr: already attempted fallback'
          return @respond '500 Fallback Failed'

        debug 'cfnr: fallback on 604'
        @session.tried_fallback = true
        return send.call this, @session.fallback_destinations

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
          return send.call this, [ to_uri: @session.cfb ]

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
          return send.call this, [ to_uri: @session.cfda ]

      debug 'Call Failed'
      @session.call_failed = true
      return
