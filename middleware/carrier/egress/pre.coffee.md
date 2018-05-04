    url = require 'url'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:carrier:egress:pre"
    @include = ->
      return unless @session?.direction is 'egress'
      ccnq_username = @req.header 'X-RU'

      @session.cdr_direction = @session.direction

      await @set
        ccnq_direction: @session.direction
        ccnq_profile: @session.profile
        ccnq_from_e164: @source
        ccnq_to_e164: @destination
        sip_cid_type: 'pid'
        progress_timeout: 16
        call_timeout: 300
        t38_passthru: true

* doc.CDR Call Detail Records (normally stored in one or multiple separate database).
* doc.CDR.variables.ccnq_extra (string) Content of the hdr.X-Ex header.
* doc.CDR.variables.ccnq_attrs (string:JSON) Content of the hdr.X-At header.
* doc.CDR.variables.ccnq_username (string) Username, content of the hdr.X-RU header (if present).
* doc.CDR.variables.ccnq_account (string) Account, username part of the hdr.P-Charge-Info standard header.
* hdr.X-Ex Copied into the `ccnq_extra` variable (shows up in CDRs).
* hdr.X-At Copied into the `ccnq_attrs` variable (shows up in CDRs).
* hdr.P-Charge-Info The username part is copied into the `ccnq_account` variable (shows up in CDRs).

        ccnq_extra: @req.header 'X-Ex'
        ccnq_attrs: @req.header 'X-At'
        ccnq_username: ccnq_username
        ccnq_account: url.parse(@req.header 'P-Charge-Info').auth

      await @unset 'sip_h_p-charge-info'

      await @export
        sip_wait_for_aleg_ack: true
        t38_passthru: true
        sip_enable_soa: false

      return
