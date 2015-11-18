    seem = require 'seem'
    pkg = require '../../../package.json'
    assert = require 'assert'
    @name = "#{pkg.name}:middleware:client:ingress:post"
    debug = (require 'debug') @name
    url = require 'url'

Use fr-ring for default ringback

    default_ringback = '%(1500,3500,440)'

Call-Handler
============

    @include = seem ->

      return unless @session.direction is 'ingress'

      debug 'Ready',
        dialplan: @session.dialplan
        destination: @destination
        number_domain: @session.number_domain

      assert @session.number_domain?, 'Missing number_domain'

One of the national translations should have mapped us to a different dialplan (e.g. 'national').

      if @session.dialplan is 'e164'
        return @respond '484'

      dst_number = "#{@destination}@#{@session.number_domain}"
      @session.number = yield @cfg.prov.get "number:#{dst_number}"

      debug "Got dst_number #{dst_number}", @session.number

      if @session.number.disabled
        debug "Number #{dst_number} is disabled"
        return @respond '486 Administratively Forbidden' # was 403

Call rejection: reject anonymous caller

      if @session.number.reject_anonymous
        if @session.caller_privacy
          # return @respond '603 Decline (anonymous)'
          yield @action 'answer'

`provisioning` is a `nimble-direction` convention.

          yield @action 'playback', "#{@cfg.provisioning}/config%3Avoice_prompts/reject-anonymous.wav"
          return @action 'hangup'

      if @session.number.use_blacklist or @session.number.use_whitelist
        pid = @req.header 'P-Asserted-Identity'
        caller = if pid? then url.parse(pid).auth else @source
        list_id = "list:#{dst_number}@#{caller}"
        debug "Number #{dst_number}, requesting caller #{caller} list #{list_id}"
        list = yield @cfg.prov.get(list_id).catch -> {}
        unless list.disabled
          if @session.number.use_blacklist and list.blacklist
            return @respond '486 Decline (blacklisted)' # was 603
          if @session.number.use_whitelist and not list.whitelist
            return @respond '486 Decline (not whitelisted)' # was 603

So far we have no reason to reject the call.

      yield set_params.call this

      {cfa,cfa_enabled,cfb,cfda,cfnr} = @session.number

      if cfa? and cfa_enabled isnt false
        @session.uris = [cfa]
        return

      if cfb? or cfda?
        @action 'ring_ready', '180 Simulated Ringing in case of forwarding'

`set_params`
============

Non-call-handling-specific parameters (these are set on all calls independently of call treatment).

    set_params = seem ->
      debug 'set_params'

      @session.endpoint = yield @cfg.prov.get("endpoint:#{@session.number.endpoint}").catch -> null

      dlg_timeout = @session.number.dialog_timer ? 28000 # 8h
      fr_inv_timeout = @session.number.inv_timer ? 90
      fr_timeout = @session.number.timer ? 2 # Unused

Maximal call duration

Note: tough-rate uses `dialog_timeout` for this (which isn't on the wiki).

      yield @action 'sched_hangup', "+#{dlg_timeout}"

      yield @set

These are injected so that they may eventually show up in CDRs.

          ccnq_direction: @session.direction
          ccnq_account: @session.number.account
          ccnq_profile: @session.profile
          ccnq_from_e164: @session.ccnq_from_e164
          ccnq_to_e164: @session.ccnq_to_e164

Transfers execute in the context defined in ../conf/refer.

          force_transfer_context: 'refer'

Other SIP parameters

[progress timeout = PDD](https://wiki.freeswitch.org/wiki/Channel_Variables#progress_timeout)
counts from the time the INVITE is placed until a progress indication (e.g. 180, 183) is received. Controls Post-Dial-Delay on this leg.

          progress_timeout:18

[call timeout = useless, use originate timeout or leg timeout](https://wiki.freeswitch.org/wiki/Channel_Variables#call_timeout)

          call_timeout:300

[originate timeout](https://wiki.freeswitch.org/wiki/Channel_Variables#originate_timeout)
Note: tough-rate uses `answer_timeout`, the wiki mentions `bridge_answer_timeout`.

          originate_timeout:fr_inv_timeout

          sip_contact_user: @session.ccnq_from_e164
          effective_caller_id_number: @source
          sip_cid_type: 'pid'
          'sip_h_X-CCNQ3-Number-Domain': @session.number_domain

These should not be forwarded towards customers.

          'sip_h_X-CCNQ3-Attrs': null
          'sip_h_X-CCNQ3-Endpoint': @session.number.endpoint
          'sip_h_X-CCNQ3-Extra': null
          'sip_h_X-CCNQ3-Location': null
          'sip_h_X-CCNQ3-Registrant-Password': null
          'sip_h_X-CCNQ3-Registrant-Realm': null
          'sip_h_X-CCNQ3-Registrant-Target': null
          'sip_h_X-CCNQ3-Routing': null

Ringbacks

          'ringback': @cfg.ringback ? default_ringback
          'instant_ringback': false
          'transfer_ringback': @cfg.ringback ? default_ringback

      yield @export
        t38_passthru:true
        sip_wait_for_aleg_ack:true
        'sip_h_X-CCNQ3-Number-Domain': @session.number_domain
        'sip_h_X-CCNQ3-Endpoint': @session.number.endpoint

      debug 'OK'
      return
