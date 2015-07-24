    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:post"
    @include = seem ->

      return unless @session.direction is 'ingress'

One of the national translations should have mapped us to a different dialplan (e.g. 'national').

      if @session.dialplan is 'e164'
        return @respond 'INVALID_NUMBER_FORMAT'

      assert @session.number_domain

      dst_number = "#{@destination}@#{@session.number_domain}"
      @session.number = yield @cfg.prov.get "number:#{dst_number}"

      ###

      if @session.number.disabled
        return @respond '480 Administratively Forbidden'

Call rejection: reject anonymous caller

      if @session.number.reject_anonymous
        if is_privacy 'id'
          return @respond '603 Decline (anonymous)'

      if @session.number.use_blacklist or @session.number.use_whitelist
        list_id = "list:#{@dst_number}@#{url.parse(@req.header 'P-Asserted-Identity').auth}"
        list = yield @cfg.prov.get(list_id).catch -> {}
        unless list.disabled
          if @session.number.use_blacklist and list.blacklist
            return @respond '603 Decline (blacklisted)'
          unless @session.number.use_whitelist and list.whitelist
            return @repond '603 Decline (not whitelisted)'


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
          ccnq_profile: @cfg.profile_name
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

      @export
        t38_passthru:true
        sip_wait_for_aleg_ack:true
