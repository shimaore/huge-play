    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:local-number"
    debug = (require 'tangible') @name

    @include = seem ->

      return unless @session.direction is 'ingress'

Global number provides inbound routing
--------------------------------------

Now, we have two cases:
- either the global-number record contains the information we need to do translation (except for the source, which is why this module needs to be inserted between the national translations, and the Centrex routing modules), and we use that information;
- or it doesn't and we use a specific middleware to do the translation (based on the destination number, typically, to put that number in a specific `national` dialplan). The `france` module in the current directory illustrates this.

* doc.global_number.local_number (string) The identifier of the local-number into which this global-number gets translated for inbound calls. (The identifier must have the format `<number>@<number-domain>` and a `number:<number>@<number-domain>` record must exist.)

      return unless @session.e164_number?.local_number?
      @tag "number:#{@session.e164_number.local_number}"

These are used e.g. for Centrex, and override the destination number and number-domain.

Note: we still keep going through the national modules because we need source number translation from `e164` to `national`.


      debug 'Using local_number'

The dialplan and country (and other parameters) might also be available in the `number_domain:` record and should be loaded from there if the global-number does not specify them.

* session.number_domain (string) The number-domain of the current destination.
* session.number_domain_data (object) If present, the content of the `number_domain:<number-domain>` record for the current `session.number_domain`.
* doc.number_domain (object) Record describing a number-domain.
* doc.number_domain._id (required) `number_domain:<number-domain>`
* doc.number_domain.type (required) `number_domain`
* doc.number_domain.number_domain (required) `<number-domain>`

      [number,number_domain] = @session.e164_number.local_number.split '@'
      @destination = number
      @session.number_domain = number_domain

      @session.number_domain_data = yield @cfg.prov
        .get "number_domain:#{number_domain}"
        .catch (error) =>
          debug "number_domain #{number_domain}: #{error.stack ? error}"
          {}
      @tag @session.number_domain_data._id
      @user_tags @session.number_domain_data.tags

* doc.number_domain.dialplan (optional) dialplan used for ingress calls to this domain.
* doc.number_domain.country (optional) country used for ingress calls to this domain.

      @session.timezone = @session.number_domain_data?.timezone ? @session.e164_number.timezone
      @session.dialplan = @session.number_domain_data?.dialplan ? @session.e164_number.dialplan
      @session.country  = @session.number_domain_data?.country  ? @session.e164_number.country
      if @session.country?
        @session.country = @session.country.toLowerCase()

      @report state:'local-number'
      debug 'OK'
      return
