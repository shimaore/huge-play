    seem = require 'seem'
    pkg = require '../../../package.json'
    assert = require 'assert'
    @name = "#{pkg.name}:middleware:client:ingress:post"
    debug = (require 'debug') @name
    url = require 'url'
    @include = seem ->

      return unless @session.direction is 'ingress'

      debug 'Ready',
        dialplan: @session.dialplan
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
          unless @session.number.use_whitelist and list.whitelist
            return @repond '486 Decline (not whitelisted)' # was 603


      ###
      FIXME

      dlg_timeout = @session.number.dialog_timer
      fr_inv_timeout = @session.number.inv_timer
      fr_timeout = @session.number.timer

      {cfa,cfb,cfda,cfnr} = @session.number

      if cfb or cfda
        @action FIXME, '180 Simulated Ringing in case of forwarding'

      if cfa
        append_to_reply 'Diversion: $ru;reason=unconditional'
        append_to_reply 'Contact: #{cfa}'
        FIXME: should call the cfa, instead
        return @respond '302 Call Forward All'

      / FIXME

      FIXME!!

      if (receive response for cfnr)
        append_to_reply 'Diversion: $ru;reason=unavailable'
        append_to_reply 'Contact: #{cfnr}'
        return @respond '302 Not Registered'



      # @session.endpoint_data = yield @cfg.prov.get "endpoint:#{@session.number_data.endpoint}"

      ###

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

          progress_timeout:18
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

      yield @export
        t38_passthru:true
        sip_wait_for_aleg_ack:true

      debug 'OK'
      return
