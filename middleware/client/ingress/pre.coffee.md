This module should be called before 'local/carrier-ingress' and before 'client-sbc/$${profile_type}-ingress'

    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:pre"
    debug = (require 'debug') @name
    @include = seem ->
      return unless @session.direction is 'ingress'

      debug 'Ready'

E.164
-----

All ingress calls come in as E.164 (with plus sign).

      @session.dialplan = 'e164'
      @session.ccnq_from_e164 = @source
      @session.ccnq_to_e164 = @destination

Global number
-------------

We retrieve the *global-number* record based on the destination.

      @session.e164_number = yield @cfg.prov.get "number:#{@session.ccnq_to_e164}"

Now, we have two cases:
- either the global-number record contains the information we need to do translation, and we use that information;
- or it doesn't and we use a specific middleware to do the translation (based on the destination number, typically, to put that number in a specific `national` dialplan). The `france` module in the current directory illustrates this.

The global number might contain additional FreeSwitch variables. Load these extra variables from the record.

      if @session.e164_number.fs_variables?
        debug 'Using fs_variables'
        yield @set @session.e164_number.fs_variables

Global number provides inbound routing
--------------------------------------

These are used e.g. for Centrex.

If these variables are provided then we will directly translate (instead of using the national modules).
Note: the source number is not translated, it is up to the proper module to translate the source.

      if @session.e164_number.local_number?
        debug 'Using local_number'

The dialplan and country (and other parameters) might also be available in the `number_domain:` record and should be loaded from there if the global-number does not specify them.

        [number,number_domain] = @session.e164_number.local_number.split '@'

Retrieve number data.

        @destination = number
        @session.number = yield @cfg.prov
          .get "number:#{number}@#{number_domain}"

Default the targets list to using `endpoint_via` if it is present.

      if @session.number.endpoint_via?
        @session.targets = [@session.number.endpoint_via]

Retrieve number-domain data.
FIXME: Use caching.

        @session.number_domain = number_domain
        @session.number_domain_data = yield @cfg.prov
          .get "number_domain:#{number_domain}"
          .catch (error) =>
            debug "number_domain #{number_domain}: #{error}"
            {}

        @session.dialplan = @session.number_domain_data?.dialplan ? @session.e164_number.dialplan
        @session.country  = @session.number_domain_data?.country  ? @session.e164_number.country

      if @session.e164_number.voicemail_main
        debug 'Using voicemail_main'
        @session.direction = 'voicemail'
        @destination = 'main'
        @session.language = @session.e164_number.language

      debug 'OK'
      return
