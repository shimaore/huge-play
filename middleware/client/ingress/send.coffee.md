    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:send"
    debug = (require 'tangible') @name
    Solid = require 'solid-gun'

    Unique_ID = 'Unique-ID'

    make_id = ->
      Solid.time() + Solid.uniqueness()

    default_eavesdrop_timeout = 8*3600 # 8h
    default_intercept_timeout = 8*3600 # 8h

    @include = ->

      return unless @session?.direction is 'ingress'

      debug 'Ready'

* session.initial_destinations (array) On ingress, client-side calls, list of target routes for `mod_sofia`, each route consisting of an object containing a `to_uri` URI (to be used with the standard SIP profile defined in session.sip_profile ) and an optional `parameters` array of per-leg parameter strings.

There might no `initial_destinations` if the call was rejected in ornaments, reject-anonymous, etc.

      if @session.initial_destinations?.length > 0
        send.call this, @session.initial_destinations

send
====

Send call to (OpenSIPS or other) with processing for CFDA, CFNR, CFB.

    @send = send = (destinations) ->

We must create a new call ID to differentiate the ingress call leg from the call leg towards
the agent (for screetching-eggs/monitor and black-metal).

      new_uuid = make_id()

      {eavesdrop_timeout,intercept_timeout} = @cfg
      eavesdrop_timeout ?= default_eavesdrop_timeout
      intercept_timeout ?= default_intercept_timeout

      key = "#{@destination}@#{@session.number_domain}"

      intercept_key = "inbound_call:#{key}"
      await @local_redis?.setex intercept_key, intercept_timeout, @call.uuid

      @session.agent = key

Eavesdrop registration
----------------------

      eavesdrop_key = "inbound:#{key}"
      {queuer} = @cfg

Transfer-disposition values:
- `recv_replace`: we transfered the call out (blind transfer). (REFER To)
- `replaced`: we accepted an inbound, supervised-transfer call. (Attended Transfer on originating session.)
- `bridge`: we transfered the call out (supervised transfer).

      unless @call.closed or @session.dialplan isnt 'centrex'

        debug 'Set inbound eavesdrop', eavesdrop_key
        await @local_redis?.setex eavesdrop_key, eavesdrop_timeout, new_uuid

The new call leg will always be bound to this agent.

        debug 'CHANNEL_PRESENT', key, new_uuid

Bind the agent to the call.

        if queuer? and @queuer_call?

          new_call = await @queuer_call new_uuid
          await queuer.set_agent new_call, key

Note: inside the queuer, these calls are never pooled, so their state does not evolve.

        @report event:'start-of-call', agent:key, call:new_uuid

Send the call(s)
----------------

      sofia = destinations.map ({ parameters = [], to_uri },index) =>
        if index is 0
          "[origination_uuid=#{new_uuid},#{parameters.join ','}]sofia/#{@session.sip_profile}/#{to_uri}"
        else
          "[#{parameters.join ','}]sofia/#{@session.sip_profile}/#{to_uri}"

      debug 'send', sofia

      await @set
        continue_on_fail: true

      debug 'Bridging', sofia

      @report state: 'ingress-bridging'

      res = await @action 'bridge', sofia.join ','

      await @local_redis?.del intercept_key

Post-attempt handling
---------------------

      data = res.body
      @session.bridge_data ?= []
      @session.bridge_data.push data

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

      disposition = data?.variable_transfer_disposition

      debug 'Outcome', {cause,code,disposition}

### For transfers, we also get state information.

- `variable_transfer_disposition: 'replaced'` (Attended Transfer on originating session)
- `variable_endpoint_disposition: 'ATTENDED_TRANSFER', 'BLIND_TRANSFER'

      @session.was_connected = cause in ['NORMAL_CALL_CLEARING', 'NORMAL_CLEARING', 'SUCCESS']
      @session.was_transferred = data.variable_transfer_history? or data.variable_endpoint_disposition is 'BLIND_TRANSFER' or data.variable_endpoint_disposition is 'ATTENDED_TRANSFER'
      @session.was_picked = cause in ['PICKED_OFF']

Success
-------

No further processing in case of success.

      if @session.was_connected
        debug "Successful call when routing #{@destination} through #{sofia.join ','}"
        @notify state: 'answered'
        return

      if @session.was_transferred
        debug "Transferred call when routing #{@destination} through #{sofia.join ','}"
        @notify state: 'transferred'
        return

      @notify event: 'missed'

      if @session.was_picked
        debug "Picked call when routing #{@destination} through #{sofia.join ','}"
        @notify state: 'picked', from_agent: key
        return

Note: we do not hangup since some centrex scenarios might want to do post-call processing (survey, ...).

Not Registered
--------------

OpenSIPS marker for not registered

      if code is '604'
        await debug.csr 'not-registered',
          destination: @destination
          enpoint: @session.endpoint_name
          tried_cfnr: @session.tried_cfnr

      if code is '604' and not @session.tried_cfnr
        @report state: 'not-registered'

        @session.reason = 'unavailable' # RFC5806
        if @session.cfnr_voicemail
          debug 'cfnr:voicemail'
          @destination = @session.cfnr_voicemail_number
          @direction 'voicemail'
          return
        if @session.cfnr_number?
          debug 'cfnr:forward'
          @session.destination = @session.cfnr_number
          @direction 'forward'
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
        @report state: 'user-busy'

        @session.reason = 'user-busy' # RFC5806
        if @session.cfb_voicemail
          debug 'cfb: voicemail'
          @destination = @session.cfb_voicemail_number
          @direction 'voicemail'
          return
        if @session.cfb_number?
          debug 'cfb:number'
          @session.destination = @session.cfb_number
          @direction 'forward'
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
        @report state: 'no-answer'

        @session.reason = 'no-answer' # RFC5806
        if @session.cfda_voicemail
          debug 'cfda: voicemail'
          @destination = @session.cfda_voicemail_number
          @notify state: 'forward-no-answer-to-voicemail'
          @direction 'voicemail'
          return
        if @session.cfda_number?
          debug 'cfda:number'
          @session.destination = @session.cfda_number
          @notify state: 'forward-no-answer-to-number'
          @direction 'forward'
          return
        if @session.cfda?
          debug 'cfda: fallback'
          @session.tried_cfda = true
          @notify state: 'forward-no-answer'
          return send.call this, [ to_uri: @session.cfda ]

      debug 'Call Failed'
      @session.call_failed = true
      @notify state: 'failed'
      return
