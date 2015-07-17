    seem = require 'seem'
    @name = 'ingress (client)'
    @include = seem ->

      return unless @session.direction is 'ingress'
      unless @session.dialplan is 'national'
        return @respond 'INVALID_NUMBER_FORMAT'

      yield @set

These are injected so that they may eventually show up in CDRs.

          ccnq_direction: @session.direction
          ccnq_account: @session.ccnq_account
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
          'sip_h_X-CCNQ3-Endpoint': null
          'sip_h_X-CCNQ3-Extra': null
          'sip_h_X-CCNQ3-Location': null
          'sip_h_X-CCNQ3-Registrant-Password': null
          'sip_h_X-CCNQ3-Registrant-Realm': null
          'sip_h_X-CCNQ3-Registrant-Target': null
          'sip_h_X-CCNQ3-Routing': null

      @export
        t38_passthru:true
        sip_wait_for_aleg_ack:true
