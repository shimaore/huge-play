    seem = require 'seem'
    pkg = require '../../../package.json'
    assert = require 'assert'
    @name = "#{pkg.name}:middleware:client:ingress:post"
    debug = (require 'debug') @name
    url = require 'url'

Use fr-ring for default ringback

    default_ringback = '%(1500,3500,440)'
    default_music = 'tone_stream://%(300,10000,440);loops=-1'

Call-Handler
============

    @include = seem ->

      return unless @session.direction is 'ingress'

      debug 'Ready',
        dialplan: @session.dialplan
        destination: @destination
        number_domain: @session.number_domain

      assert @session.number_domain?, 'Missing number_domain'

Routing
-------

One of the national translations should have mapped us to a different dialplan (e.g. 'national').

      if @session.dialplan is 'e164'
        return @respond '484'

Retrieve number data.

* session.number (object) The record of the destination number interpreted as a local-number in `session.number_domain`.
* doc.local_number.disabled (boolean) If true the record is not used.

      dst_number = "#{@destination}@#{@session.number_domain}"
      @session.number = yield @cfg.prov.get("number:#{dst_number}").catch (error) -> {disabled:true,error}

      if @session.number.error?
        debug "Could not locate destination number #{dst_number}: #{error}"
        return @respond '486 Not Found'

      debug "Got dst_number #{dst_number}", @session.number

      if @session.number.disabled
        debug "Number #{dst_number} is disabled"
        return @respond '486 Administratively Forbidden' # was 403

Call rejection: reject anonymous caller

* doc.local_number.reject_anonymous (boolean) If true, rejects anonymous calls.
* session.caller_privacy (boolean) Indicates if the caller requested privacy.
* doc.local_number.reject_anonymous_to_voicemail (boolean) If true, rejected anonymous calls are sent to voicemail. If false, they are rejected with an error message.
* doc.config%3Avoice_prompts/reject-anonymous.wav The attachment played when an inbound anonymous call is rejected and the call is not sent to voicemail.

      if @session.number.reject_anonymous
        if @session.caller_privacy
          if @session.number.reject_anonymous_to_voicemail
            debug 'reject anonymous: send to voicemail'
            @session.direction = 'voicemail'
            return

          debug 'reject anonymous'
          # return @respond '603 Decline (anonymous)'
          yield @action 'answer'

`provisioning` is a `nimble-direction` convention.

          yield @action 'playback', "#{@cfg.provisioning}/config%3Avoice_prompts/reject-anonymous.wav"
          return @action 'hangup'

* doc.local_number.use_blacklist (boolean) If true and a `list:<destination-number>@<calling-number>` record exists, where `<destination-number>` is the identifier of a local-number (in the format `<number>@<number-domain>`), use that record to decide whether to reject the inbound call based on the calling number.
* doc.local_number.use_whitelist (boolean) If true and a `list:<destination-number>@<calling-number>` record exists, where `<destination-number>` is the identifier of a local-number (in the format `<number>@<number-domain>`), use that record to decide whetehr to accept the inbound call.
* doc.list A record indicating whether to accept a inbound call or reject it. The identifier is `list:<number>@<number-domain>@<caller>` with `<number>` and `<caller>` interpreted in the given number-domain.
* doc.list.disabled (boolean) If true, proceed as-if the record did not exist.
* doc.list.blacklist (boolean) If true, the call is rejected.
* doc.list.whitelist (boolean) If false, the call is rejected.
* doc.local_number.list_to_voicemail (boolean) If true, calls rejected by blacklist or whitelist are forwarded to voicemail. Otherwise calls are rejected without any error message. Default: false.

      if @session.number.use_blacklist or @session.number.use_whitelist
        pid = @req.header 'P-Asserted-Identity'
        caller = if pid? then url.parse(pid).auth else @source
        list_id = "list:#{dst_number}@#{caller}"
        debug "Number #{dst_number}, requesting caller #{caller} list #{list_id}"
        list = yield @cfg.prov.get(list_id).catch -> {}
        unless list.disabled
          if @session.number.use_blacklist and list.blacklist
            if @session.number.list_to_voicemail
              @session.direction = 'voicemail'
              return
            return @respond '486 Decline (blacklisted)' # was 603
          if @session.number.use_whitelist and not list.whitelist
            if @session.number.list_to_voicemail
              @session.direction = 'voicemail'
              return
            return @respond '486 Decline (not whitelisted)' # was 603

* doc.local_number.custom_ringback (boolean,string) If present, a custom ringback is played while the call is being presented to the destination user. The ringback file is an attachment located in `doc.voicemail_settings`; its name is the value of `custom_ringback`, or `ringback.wav` if `custom_ringback` is `true`. Default: plays system-wide `cfg.ringback`, or a code-assigned default ringback.

      if @session.number.custom_ringback is true
        @session.ringback ?= [
          @cfg.userdb_base_uri
          @session.number.user_database
          'voicemail_settings'
          'ringback.wav'
        ].join '/'

      if typeof @session.number.custom_ringback is 'string'
        @session.ringback ?= [
          @cfg.userdb_base_uri
          @session.number.user_database
          'voicemail_settings'
          @session.number.custom_ringback
        ].join '/'

* doc.local_number.custom_music (boolean,string) If present, a custom music is played while the call is put on-hold. The music-on-hold file is an attachment located in `doc.voicemail_settings`; its name is the value of `custom_music`, or `music.wav` if `custom_ringback` is `true`. Default: plays system-wide `cfg.music`, or a code-assigned default music (bips).

      if @session.number.custom_music is true
        @session.music ?= [
          @cfg.userdb_base_uri
          @session.number.user_database
          'voicemail_settings'
          'music.wav'
        ].join '/'

      if typeof @session.number.custom_music is 'string'
        @session.music ?= [
          @cfg.userdb_base_uri
          @session.number.user_database
          'voicemail_settings'
          @session.number.custom_music
        ].join '/'

So far we have no reason to reject the call.

      yield set_params.call this

`CF...` can be either configured as URIs (number.cfa etc. -- bypasses controls) or as plain numbers (will use the `forward` direction for access control).

* session.cf_active (boolean) true if any type of call forwarding is present on the local-number
* doc.local_number.cfa_enabled (boolean) If false, Call Forward All is disabled.
* doc.local_number.cfb_enabled (boolean) If false, Call Forward on Busy is disabled.
* doc.local_number.cfnr_enabled (boolean) If false, Call Forward on Not Registered is disabled.
* doc.local_number.cfda_enabled (boolean) If false, Call Forward on Don't Answer is disabled.
* doc.local_number.cfa_voicemail (boolean) If true, all incoming calls are sent to voicemail.
* doc.local_number.cfa_number (string) If present and the call is not sent to voicemail, all incoming calls are sent to this number (interpreted in the local number-domain).
* doc.local_number.cfa (string:URI) If present and the call is not sent to voicemail or forward to a number, all incoming calls are sent to this URI.
* doc.local_number.cfb_voicemail (boolean) If true, incoming Busy calls are sent to voicemail.
* doc.local_number.cfb_number (string) If present and the call is not sent to voicemail, incoming Busy calls are sent to this number (interpreted in the local number-domain).
* doc.local_number.cfb (string:URI) If present and the call is not sent to voicemail or forward to a number, incoming Busy calls are sent to this URI.
* doc.local_number.cfnr_voicemail (boolean) If true, incoming Not Registered calls are sent to voicemail.
* doc.local_number.cfnr_number (string) If present and the call is not sent to voicemail, incoming Not Registered calls are sent to this number (interpreted in the local number-domain).
* doc.local_number.cfnr (string:URI) If present and the call is not sent to voicemail or forward to a number, incoming Not Registered calls are sent to this URI.
* doc.local_number.cfda_voicemail (boolean) If true, incoming Don't Answer calls are sent to voicemail.
* doc.local_number.cfda_number (string) If present and the call is not sent to voicemail, incoming Don't Answer calls are sent to this number (interpreted in the local number-domain).
* doc.local_number.cfda (string:URI) If present and the call is not sent to voicemail or forward to a number, incoming Don't Answer calls are sent to this URI.

      @session.cf_active = false
      for name in ['cfa','cfb','cfnr','cfda']
        do (name) =>
          return if @session.number["#{name}_enabled"] is false
          v = @session["#{name}_voicemail"] = @session.number["#{name}_voicemail"]
          n = @session["#{name}_number"]    = @session.number["#{name}_number"]
          p = @session[name]                = @session.number[name]
          @session.cf_active = @session.cf_active or v? or n? or p?

Call Forward All
----------------

* session.reason (string) The RFC5806 `reason` field for call forwarding.

      @session.reason = 'unconditional' # RFC5806
      if @session.cfa_voicemail
        debug 'cfa:voicemail'
        @session.direction = 'voicemail'
        return
      if @session.cfa_number?
        debug 'cfa:forward'
        @session.direction = 'forward'
        @session.destination = @session.cfa_number
        return
      if @session.cfa?
        debug 'cfa:fallback'
        @session.uris = [@session.cfa]
        return
      @session.reason = null

Ringback for other Call Forward
-------------------------------

* cfg.answer_for_ringback (boolean) If true, answer the call (200 OK) instead of pre-answering the call (183 with Media) for custom ringback.
* cfg.ready_for_ringback (boolean) If true, inbound calls are ring-ready (180 without media) immediately, without waiting for the customer device to provide ringback.
* doc.local_number.ring_ready (boolean) If true, inbound calls are ring-ready (180 without media) immediately, without waiting for the customer device to provide ringback.

      if @session.number.custom_ringback
        if @cfg.answer_for_ringback
          debug 'answer for ringback'
          yield @action 'answer' # 200
          yield @set sip_wait_for_aleg_ack:false
          @session.wait_for_aleg_ack = false
        else
          debug 'pre_answer for ringback'
          yield @action 'pre_answer' # 183
      else
        if @session.cf_active or @cfg.ready_for_ringback or @session.number.ring_ready
          debug 'cf_active'
          yield @action 'ring_ready' # 180

Default the targets list to using `endpoint_via` if it is present.

* doc.local_number.endpoint_via (string:domain) If present, inbound calls are sent to the specified domain. (See `session.targets`.)

      if @session.number.endpoint_via?
        @session.targets ?= [@session.number.endpoint_via]

      return

`set_params`
============

Non-call-handling-specific parameters (these are set on all calls independently of call treatment).

    set_params = seem ->
      debug 'set_params'

      @session.ringback ?= @cfg.ringback
      @session.ringback ?= default_ringback

      @session.music ?= @cfg.music
      @session.music ?= default_music

* doc.local_number.endpoint (string) The name of the endpoint where calls for this number should be sent. A matching `endpoint:<endpoint>` record must exist.
* doc.session.endpoint (object) The endpoint record for the inbound local-number's `endpoint`.

      @session.endpoint = yield @cfg.prov.get("endpoint:#{@session.number.endpoint}").catch -> null

* doc.local_number.dialog_timer (number) Maximum duration of a call for this local-number.
* doc.local_number.inv_timer (number) Maximum progress duration for this local-number. Typically this is the duration before the call is sent to voicemail.

      dlg_timeout = @session.number.dialog_timer ? 28000 # 8h
      fr_inv_timeout = @session.number.inv_timer ? 90
      fr_timeout = @session.number.timer ? 2 # Unused

Maximal call duration

Note: tough-rate uses `dialog_timeout` for this (which isn't on the wiki).

      yield @action 'sched_hangup', "+#{dlg_timeout}"

      yield @set

These are injected so that they may eventually show up in CDRs.

* doc.local_number.account (string) Account information for this number. Normally not present, since the account information from the endpoint is used. Overrides the endpoint's account information if present.

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

          ringback: @session.ringback # Used for pre_answer
          instant_ringback: false
          transfer_ringback: @session.ringback # Used after answer

* hdr.X-CCNQ3-Number-Domain Set on inbound calls to the number-domain of the local-number.
* hdr.X-CCNQ3-Endpoint Set on inbound calls to the endpoint of the local-number.

      yield @export
        t38_passthru:true
        sip_wait_for_aleg_ack: @session.wait_for_aleg_ack ? true
        'sip_h_X-CCNQ3-Number-Domain': @session.number_domain
        'sip_h_X-CCNQ3-Endpoint': @session.number.endpoint
        originate_timeout:fr_inv_timeout
        bridge_answer_timeout:fr_inv_timeout

Music

        hold_music: @session.music

      debug 'OK'
      return
