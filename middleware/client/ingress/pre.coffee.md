This module should be called before 'local/carrier-ingress' and before 'client-sbc/$${profile_type}-ingress'

    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:pre"
    debug = (require 'debug') @name
    @include = seem ->
      return unless @session.direction is 'ingress'

Do not process here if the dialplan is already known (e.g. because Centrex sent us here).

      if @session.dialplan?
        debug 'Dialplan already set, skipping'
        return

      debug 'Ready'

E.164
-----

All external ingress calls come in as E.164 (with plus sign).

      @session.dialplan = 'e164'
      @session.ccnq_from_e164 = @source
      @session.ccnq_to_e164 = @destination

Global number
-------------

We retrieve the *global-number* record based on the destination.

      @session.e164_number = yield @cfg.prov.get "number:#{@session.ccnq_to_e164}"

The global number might contain additional FreeSwitch variables. Load these extra variables from the record.

      if @session.e164_number.fs_variables?
        debug 'Using fs_variables'
        yield @set @session.e164_number.fs_variables

      if @session.e164_number.voicemail_main
        debug 'Using voicemail_main'
        @session.direction = 'voicemail'
        @destination = 'main'
        @session.language = @session.e164_number.language

      debug 'OK'
      return
