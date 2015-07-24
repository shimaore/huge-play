This module should be called before 'local/carrier-ingress' and before 'client-sbc/$${profile_type}-ingress'

    seem = require 'seem'
    @name = 'client/ingress/pre'
    @include = seem ->
      return unless @session.direction is 'ingress'

      @session.dialplan = 'e164'
      @session.ccnq_from_e164 = @source
      @session.ccnq_to_e164 = @destination

      @session.e164_number = yield @prov.get "number:#{@session.ccnq_to_e164}"

These are used e.g. for Centrex. Haven't established conventions for that yet, though.

Load extra variables from record.

      if @session.e164_number.fs_variables?
        yield @set @session.e164_number.fs_variables

Directly translate (do not use the national modules).

      if @session.e164_number.local_number?
        assert @session.e164_number.dialplan?, "Missing dialplan for number #{@destination}"
        assert @session.e164_number.country?, "Missing country for number #{@destination}"

        @session.dialplan = @session.e164_number.dialplan
        @session.country = @session.e164_number.country
        [number,number_domain] = @session.e164_number.local_number.split '@'
        @session.number_domain = number_domain
        @destination = number
