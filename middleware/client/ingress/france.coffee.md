    seem = require 'seem'
    @name = 'france-ingress'
    @include = seem ->

      return unless @session.direction is 'ingress'
      return unless @session.dialplan is 'e164'

Rewrite destination
===================

      switch

to: french number

        when $ = @destination.match /^33([1-9][0-9]+)$/
          @session.ccnq_to_e164 = @destination
          @destination = "0#{$[1]}"
          @session.country = 'fr'

        else
          return

Rewrite source
==============

      switch

from: national number

        when $ = @source.match /^33([0-9]+)$/
          @session.ccnq_from_e164 = @source
          @source = "0#{$[1]}"

from: international number

        when $ = @source.match /^([1-9][0-9]+)$/
          @session.ccnq_from_e164 = @source
          @source = "00#{$[1]}"

        else
          return @respond 'INVALID_NUMBER_FORMAT'

Update the dialplan
===================

      @session.dialplan = 'national'

Handle privacy request
======================

Privacy: id or other requested privacy

TODO: populate `@session.privacy_hide_number`

      if @session.privacy_hide_number
        @source = 'anonymous'
        yield @action 'privacy', 'full'
        yield @set
          effective_caller_id_name: '_undef_'
          effective_caller_id_number: 'anonymous'
          origination_privacy: 'screen+hide_name+hide_number'
