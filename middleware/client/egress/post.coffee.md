    pkg = require '../../../package.json'

    seem = require 'seem'
    url = require 'url'

    @name = "#{pkg.name}/middleware/client/egress/post"
    debug = (require 'debug') @name
    assert = require 'assert'

    @include = seem ->
      return unless @session.direction is 'egress'

      assert @cfg.profile_name, 'Missing profile_name'

      unless ccnq_from_e164?  and ccnq_to_e164?
        return @respond 'INVALID_NUMBER_FORMAT'

The URL module parses the SIP username as `auth`.

      pci = @req.header 'p-charge-info'
      unless pci?
        return @respond '403 No Charge-Info'

      @session.ccnq_account = (url.parse pci).auth
      unless @session.ccnq_account?
        return @respond '403 Invalid Charge-Info'

      yield @set

These are injected so that they may eventually show up in CDRs.

          ccnq_direction: @session.direction
          ccnq_account: @session.ccnq_account
          ccnq_profile: @cfg.profile_name
          ccnq_from_e164: @session.ccnq_from_e164
          ccnq_to_e164: @session.ccnq_to_e164

SIP parameters

          progress_timeout: 18
          call_timeout: 300
          effective_caller_id_number: @session.ccnq_from_e164
          sip_contact_user: @session.ccnq_from_e164
          sip_cid: 'pid'

      @export
        t38_passthru:true
        sip_wait_for_aleg_ack:true
