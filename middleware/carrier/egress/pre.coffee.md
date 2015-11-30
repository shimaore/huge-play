    seem = require 'seem'
    url = require 'url'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:carrier:egress:pre"
    @include = seem ->
      return unless @session.direction is 'egress'
      ccnq_username = @req.header 'CCNQ3-Registrant-Username'

      yield @set
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
        ccnq_account: url.parse(@req.header 'P-Charge-Info').auth

      yield @unset 'sip_h_p-charge-info'

      yield @export
        sip_wait_for_aleg_ack: true
        t38_passthru: true
        sip_enable_soa: false

      return
