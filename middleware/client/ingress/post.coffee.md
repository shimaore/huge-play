    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:post"
    debug = (require 'tangible') @name
    url = require 'url'

    Nimble = require 'nimble-direction'
    CouchDB = require 'most-couchdb'

    tones = require '../tones'

Use fr-ring for default ringback

    default_ringback = tones.fr.ringback

See https://freeswitch.org/jira/browse/FS-9776

    default_music = 'silence'

Call-Handler
============

    @include = ->

      return unless @session?.direction is 'ingress'

      debug 'Ready',
        dialplan: @session.dialplan
        country: @session.country
        destination: @destination
        number_domain: @session.number_domain

      unless @session.number_domain?
        debug.dev 'Missing number_domain'
        return

Routing
-------

One of the national translations should have mapped us to a different dialplan (e.g. 'national').

      if @session.dialplan is 'e164'
        return @respond '484'

Retrieve number data.

      dst_number = await @validate_local_number()

      unless dst_number?
        debug 'Number not found'
        return

      nimble = Nimble @cfg
      prov = new CouchDB nimble.provisioning

Call rejection: reject anonymous caller

* doc.local_number.reject_anonymous (boolean) If true, rejects anonymous calls.
* session.caller_privacy (boolean) Indicates if the caller requested privacy.
* doc.local_number.reject_anonymous_to_voicemail (boolean) If true, rejected anonymous calls are sent to voicemail. If false, they are rejected with an error message.
* doc.config%3Avoice_prompts/reject-anonymous.wav The attachment played when an inbound anonymous call is rejected and the call is not sent to voicemail.

      if @session.number.reject_anonymous
        if @session.caller_privacy
          if @session.number.reject_anonymous_to_voicemail
            debug 'reject anonymous: send to voicemail'
            # @destination unchanged
            @direction 'voicemail'
            return

          debug 'reject anonymous'
          @notify state: 'reject-anonymous'
          # return @respond '603 Decline (anonymous)'
          await @action 'answer'

          await @action 'playback', "#{nimble.provisioning}/config%3Avoice_prompts/reject-anonymous.wav"
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
        list = await prov.get(list_id).catch -> {}
        unless list.disabled
          if @session.number.use_blacklist and list.blacklist
            @notify state: 'blacklisted'
            if @session.number.list_to_voicemail
              # @destination unchanged
              @direction 'voicemail'
              return
            return @respond '486 Decline (blacklisted)' # was 603
          if @session.number.use_whitelist and not list.whitelist
            @notify state: 'not whitelisted'
            if @session.number.list_to_voicemail
              # @destination unchanged
              @direction 'voicemail'
              return
            return @respond '486 Decline (not whitelisted)' # was 603

* doc.local_number.custom_ringback (boolean,string) If present, a custom ringback is played while the call is being presented to the destination user. The ringback file is an attachment located in `doc.voicemail_settings`; its name is the value of `custom_ringback`, or `ringback.wav` if `custom_ringback` is `true`. Default: plays system-wide `cfg.ringback`, or a code-assigned default ringback.

      debug 'ringback', @session.ringback, @session.number.custom_ringback

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

* cfg.answer_for_ringback (boolean) If true, answer the call (200 OK) instead of pre-answering the call (183 with Media) for custom ringback.
* session.answer_for_ringback (boolean) If true, answer the call (200 OK) instead of pre-answering the call (183 with Media) for custom ringback.
* cfg.ready_for_ringback (boolean) If true, inbound calls are ring-ready (180 without media) immediately, without waiting for the customer device to provide ringback.
* session.ready_for_ringback (boolean) If true, inbound calls are ring-ready (180 without media) immediately, without waiting for the customer device to provide ringback.
* doc.local_number.ring_ready (boolean) If true, inbound calls are ring-ready (180 without media) immediately, without waiting for the customer device to provide ringback.

      debug 'Ringback'

      if @session.number.custom_ringback
        if @cfg.answer_for_ringback or @session.answer_for_ringback
          debug 'answer for ringback'
          await @action 'answer' # 200
          @session.sip_wait_for_aleg_ack = false
        else
          debug 'pre_answer for ringback'
          await @action 'pre_answer' # 183
      else
        if @session.cf_active or @cfg.ready_for_ringback or @session.ready_for_ringback or @session.number.ring_ready
          debug 'cf_active'
          await @action 'ring_ready' # 180

So far we have no reason to reject the call.

      await set_params.call this

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

Make sure we get the messages even if the call is forwarded.

          @session["#{name}_voicemail_number"] = @destination

Call Forward All
----------------

* session.reason (string) The RFC5806 `reason` field for call forwarding.

      debug 'CFA?'

      @session.reason = 'unconditional' # RFC5806
      if @session.cfa_voicemail
        debug 'cfa:voicemail'
        @notify state: 'cfa:voicemail'
        @destination = @session.cfa_voicemail_number
        @direction 'voicemail'
        return
      if @session.cfa_number?
        debug 'cfa:forward'
        @notify state: 'cfa:forward'
        @session.destination = @session.cfa_number
        @direction 'forward'
        return
      if @session.cfa?
        debug 'cfa:fallback'
        @notify state: 'cfa:fallback'
        @session.initial_destinations = [ to_uri: @session.cfa ]
        return
      @session.reason = null

Do Not Disturb
--------------

* local_number.dnd (boolean) If true, considers the line is in Do Not Disturb and use the CFB indications to handle the call.

      debug 'DND?'

      if @session.number.dnd
        @session.reason = 'do-not-disturb' # RFC5806
        if @session.cfb_voicemail
          debug 'dnd:voicemail'
          @notify state: 'dnd:voicemail'
          @destination = @session.cfb_voicemail_number
          @direction 'voicemail'
          return
        if @session.cfb_number?
          debug 'dnd:forward'
          @notify state: 'dnd:forward'
          @session.destination = @session.cfb_number
          @direction 'forward'
          return
        if @session.cfb?
          debug 'dnd:fallback'
          @notify state: 'dnd:fallback'
          @session.initial_destinations = [ to_uri: @session.cfb ]
          return
        @session.reason = null

Build the destination FreeSwitch dialstring
-------------------------------------------

Note the different alternatives for routing:
- To URI: `sofia/.../<To-URI>` (and RURI if the RURI is not specified)
- RURI: `sip_invite_req_uri`
- Route header: `sip_route_uri` = `sip:<domain-name>`
- Network destination: `sip_network_ip`, 'sip_network_port'
- `;fs_path=`

### Standard destination

      unless @session.endpoint?
        return @respond '400 Missing endpoint'

      parameters = []

* cfg.ingress_target (string:domain) Inbound domain for static endpoint: inbound calls are sent to the specified domain if the endpoint's is a static endpoint (its name does not contain `@`). (Normally points to a matching proxy.)
* doc.endpoint.via (string:domain) If present, inbound calls are sent to the specified name (instead of the domain name that is part of the endpoint's ID).

      [extension,domain] = @session.endpoint_name.split '@'

      target  = @session.endpoint.via
      target ?= @session.number.endpoint_via # legacy
      target ?= domain
      target ?= @cfg.ingress_target

Note how the destination URI (which will be mapped to the RURI and the To going to OpenSIPS) uses the original called number.
This way, when OpenSIPS does the translation to an endpoint (using the `X-En` header), the RURI will be the one the endpoint used to REGISTER, while the To will remain the original called number.

      to_uri = "sip:#{@destination}@#{target}"

Convergence
-----------

* doc.local_number.convergence_active (boolean) If true, the convergence feature is active.
* doc.local_number.convergence (array of objects) Convergence destinations and options.
* doc.local_number.convergence[].number (string) destination number (as dialed from the endpoint)
* doc.local_number.convergence[].confirm (boolean) whether to ask for confirmation after the call is answered
* doc.local_number.convergence[].confirm (string) whether to ask for confirmation after the call is answered, and which digit should be used to confirm
* doc.local_number.convergence[].delay (integer) number of seconds to wait before dialing this destination
* doc.local_number.convergence[].timeout (integer) number of seconds to wait before considering the destination as not responding

The convergence function returns a list of optional, additional targets (e.g. mobile phone destinations) which are called at the same time as the original number, or with a slight delay. This is used to implement "Follow-Me"/"Mobile Convergence"-type scenarios.

      convergence = =>

If the feature is not enabled on this line just skip.

        return [] unless @session.number.convergence? and @session.number.convergence_active

Following code lifted from place-call (esp. the conference code).

The additional calls will be sent back to ourselves, we need to figure out our host and port.

        return [] unless @cfg.session?.profile? and @cfg.profiles?

        profile = @cfg.session.profile
        {host} = @cfg
        p = @cfg.profiles[profile]
        return [] unless host and p?

        port = p.egress_sip_port ? p.sip_port+10000

Call confirmation

        confirm = @session.number.convergence_confirm
        if confirm?

The `confirm` field can be a boolean or a string.

          key = '5'
          if typeof confirm is 'string' and confirm.match /^\d$/
            key = confirm

Try hard to figure out what language we should use.

          language = @session.language
          language ?= @session.number.language
          language ?= @cfg.announcement_language
          language ?= ''

The `call_options` are used by tough-rate.

          await @reference.set_call_options
            group_confirm_key: key
            group_confirm_file: "phrase:confirm:#{key}"
            group_confirm_error_file: "phrase:confirm:#{key}"
            group_confirm_read_timeout: 15000 # defaults to 5000
            group_confirm_cancel_timeout: false
            language: language

        default_params = {}

Normally the x-ref parameters are already defined in `middleware/client/setup`.
(The `call-to-conference` function needs to define them but we should not need to.)

        # xref = "xref:#{@session.reference}"
        # default_param.sip_invite_params = xref
        # default_param.sip_invite_to_params = xref
        # default_param.sip_invite_contact_params = xref
        # default_param.sip_invite_from_params = xref

This is similar to what is done in `middleware/forward/basic`: we override the calling number if requested to.

        if @cfg.mask_source_on_forward
          default_params.origination_caller_id_number = @session.number.asserted_number ? @session.number.number

Define parameters and targets.

        @session.number.convergence
        .filter (o) -> o.number?
        .map (o) =>

          params = Object.assign {}, default_params

Delay ("Follow-Me" application)

          if o.delay
            params.leg_delay_start = o.delay

Timeout

          if o.timeout
            params.leg_timeout = o.timeout

          parameters: Object.keys(params).map (k) -> "#{k}=#{params[k]}"
          to_uri: "sip:#{o.number}@#{host}:#{port}"

      converged = await convergence()
      @session.initial_destinations ?= [
        { parameters, to_uri }
        converged...
      ]

      @notify
        state: 'ingress-call'
        endpoint: @session.endpoint_name

### Build the set of `_in` targets for notifications of the reference data.

      if @session.dev_logger
        await @reference.set_dev_logger true

      if @session.number.record_ingress
        @record_call @session.number._id

      debug 'Done.'
      return

`set_params`
============

Non-call-handling-specific parameters (these are set on all calls independently of call treatment).

    set_params = ->
      debug 'set_params'

      if @session.country? and @session.country of tones
        @session.ringback ?= tones[@session.country].ringback
        if @cfg.use_country_tones_for_music
          @session.music ?= tones.loop tones[@session.country].waiting

      @session.ringback ?= @cfg.ringback
      @session.ringback ?= default_ringback

      @session.music ?= @cfg.music
      @session.music ?= default_music

      @session.sip_wait_for_aleg_ack ?= true

      debug 'set_params',
        ringback: @session.ringback
        music: @session.music
        sip_wait_for_aleg_ack : @session.sip_wait_for_aleg_ack

      await @set
        ccnq_endpoint: @session.endpoint_name

* doc.local_number.dialog_timer (number) Maximum duration of a call for this local-number.
* doc.local_number.inv_timer (number) Maximum progress duration for this local-number. Typically this is the duration before the call is sent to voicemail.

      dlg_timeout = @session.number.dialog_timer ? 28000 # 8h
      fr_inv_timeout = @session.number.inv_timer ? 90
      fr_timeout = @session.number.timer ? 2 # Unused

Maximal call duration

Note: tough-rate uses `dialog_timeout` for this (which isn't on the wiki).

      debug 'schedule hangup'
      await @action 'sched_hangup', "+#{dlg_timeout}"

      @session.cdr_direction = @session.direction

      debug 'set parameters'
      await @set

These are injected so that they may eventually show up in CDRs.

* doc.local_number.account (string) Account information for this number. Normally not present, since the account information from the endpoint is used. Overrides the endpoint's account information if present.

          ccnq_direction: @session.direction
          ccnq_account: @session.number.account ? @session.endpoint?.account
          ccnq_profile: @session.profile
          ccnq_from_e164: @session.ccnq_from_e164
          ccnq_to_e164: @session.ccnq_to_e164

Other SIP parameters

[progress timeout = PDD](https://wiki.freeswitch.org/wiki/Channel_Variables#progress_timeout)
counts from the time the INVITE is placed until a progress indication (e.g. 180, 183) is received. Controls Post-Dial-Delay on this leg.

          progress_timeout:18

[call timeout = useless, use originate timeout or leg timeout](https://wiki.freeswitch.org/wiki/Channel_Variables#call_timeout)

          call_timeout:300

          sip_contact_user: @session.ccnq_from_e164
          effective_caller_id_number: @source
          sip_cid_type: 'pid'
          'sip_h_X-En': @session.endpoint_name

These should not be forwarded towards customers.

          'sip_h_X-At': null
          'sip_h_X-Ex': null
          'sip_h_X-RH': null
          'sip_h_X-RP': null
          'sip_h_X-RR': null
          'sip_h_X-RT': null
          'sip_h_X-RU': null

Ringbacks

          ringback: @session.ringback # Used for pre_answer
          instant_ringback: false
          transfer_ringback: @session.ringback # Used after answer

Codec negotiation with late-neg:

          inherit_codec: @session.inherit_codec ? true

* hdr.X-En Set on inbound calls to the endpoint of the local-number.

      debug 'export parameters'
      await @export
        t38_passthru:true
        sip_wait_for_aleg_ack: @session.sip_wait_for_aleg_ack
        'sip_h_X-En': @session.endpoint_name
        originate_timeout:fr_inv_timeout
        bridge_answer_timeout:fr_inv_timeout

Music

        hold_music: @session.music

      debug 'set_params: done.'
      return
