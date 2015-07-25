    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:france"
    debug = (require 'debug') @name
    @include = ->

      return unless @session.direction is 'ingress'
      return unless @session.dialplan is 'e164'

      debug 'Ready'

Rewrite destination
===================

      switch

        when $ = @destination.match /^33([1-9][0-9]+)$/
          @session.ccnq_to_e164 = @destination
          @destination = "0#{$[1]}"
          @session.country = 'fr'

        else

Destination _must_ be a France number.
Otherwise let it be parsed by another module.

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

      debug 'OK',
        source: @source
        destination: @destination
        diaplan: @session.dialplan
        country: @session.country
      return
