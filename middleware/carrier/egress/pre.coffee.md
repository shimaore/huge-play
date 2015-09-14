    @include = ->
      return unless @session.direction is 'egress'
      ccnq_username = @req.header 'CCNQ3-Registrant-Username'

      @set
        ccnq_direction: @session.direction
        ccnq_profile: @session.profile
        ccnq_from_e164: @source
        ccnq_to_e164: @destination
        sip_cid_type: 'pid'
        progress_timeout: 16
        call_timeout: 300
        t38_passthru: true

        ccnq_extra: @req.header 'X-CCNQ3-Extra'
        ccnq_attrs: @req.header 'X-CCNQ3-Attrs'
        ccnq_username: ccnq_username
        ccnq_account: url.parse(@req.header 'p-charge-info').auth

      @unset 'sip_h_p-charge-info'

      @export
        sip_wait_for_aleg_ack: true
        t38_passthru: true
