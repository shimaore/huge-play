    @include = ->
      return unless @session.direction is 'egress'
      ccnq_username = @req.header 'CCNQ3-Registrant-Username'

      @set
        ccnq_extra: @req.header 'X-CCNQ3-Extra'
        ccnq_attrs: @req.header 'X-CCNQ3-Attrs'
        ccnq_username: ccnq_username
        ccnq_account: url.parse(@req.header 'p-charge-info').auth
        ccnq_from_e164: @source
        ccnq_to_e164: @destination
        sip_cid_type: 'pid'
        progress_timeout: 16
        call_timeout: 300

      @unset 'sip_h_p-charge-info'

      @export
        sip_wait_for_aleg_ack: true
        t38_passthru: true
        sip_append_audio_sdp: 'a:ptime=20'

Cleanup caller-id

      if ccnq_username?.match /^\d+$/
        @set
          sip_contact_user: "00#{ccnq_username}"
          sip_invite_domain: @req.header 'X-CCNQ3-Registrant-Target'
          effective_caller_id_number: "00#{ccnq_username}"

      if privacy_hide_number is 'true'
        @set
          service_prefix: '3651'

Egress DO-TOM
