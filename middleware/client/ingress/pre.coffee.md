This module should be called before 'local/carrier-ingress' and before 'client-sbc/$${profile_type}-ingress'

    seem = require 'seem'
    @name = 'ingress pre (client)'
    @include = seem ->
      return unless @session.direction is 'ingress'
      @session.ccnq_from_e164 = @source
      @session.ccnq_to_e164 = @destination

These are used e.g. for Centrex. Haven't established conventions for that yet, though.

      ###
      doc = yield @prov.get "number:#{@destination}"
      if doc.local_number?
        [number,number_domain] = doc.local_number.split '@'
        @session.number_domain = number_domain
        @destination = number
      ###
