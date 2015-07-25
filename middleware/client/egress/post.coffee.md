    seem = require 'seem'
    url = require 'url'

    pkg = require '../../../package.json'
    @name = "#{pkg.name}/middleware/client/egress/post"
    debug = (require 'debug') @name
    assert = require 'assert'

    @include = seem ->
      return unless @session.direction is 'egress'

      unless @session.ccnq_from_e164? and @session.ccnq_to_e164?
        debug 'Missing e164 numbers'
        return @respond 'INVALID_NUMBER_FORMAT'

      @session.e164_number = yield @cfg.prov.get("number:#{@session.ccnq_from_e164}").catch -> {}

      if @session.e164_number.fs_variables?
        yield @set @session.e164_number.fs_variables

The URL module parses the SIP username as `auth`.

      pci = @req.header 'p-charge-info'
      pci ?= @session.e164_number.account
      unless pci?
        debug 'No Charge-Info'
        return @respond '403 No Charge-Info'

      @session.ccnq_account = (url.parse pci).auth
      unless @session.ccnq_account?
        debug 'Invalid Charge-Info'
        return @respond '403 Invalid Charge-Info'

      yield @set

These are injected so that they may eventually show up in CDRs.

          ccnq_direction: @session.direction
          ccnq_account: @session.ccnq_account
          ccnq_profile: @session.profile
          ccnq_from_e164: @session.ccnq_from_e164
          ccnq_to_e164: @session.ccnq_to_e164

SIP parameters

          progress_timeout: 18
          call_timeout: 300
          effective_caller_id_number: @session.ccnq_from_e164
          sip_contact_user: @session.ccnq_from_e164
          sip_cid: 'pid'

      debug 'OK'

      @export
        t38_passthru:true
        sip_wait_for_aleg_ack:true
