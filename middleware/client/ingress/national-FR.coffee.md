    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:national-FR"
    debug = (require 'debug') @name
    @include = ->

      return unless @session.direction is 'ingress'
      return unless @session.dialplan is 'e164'

      debug 'Ready',
        destination: @destination
        source: @source

Rewrite destination
===================

* session.ccnq_to_e164 (string) The original destination number (in E.164-sans-plus format) before translation to a national number.
* session.country (string) Two-letter name of the country in which a national number must be interpreted. Typically used when `session.dialplan` equals `national`.

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

* session.ccnq_from_e164 (string) The original calling number (in E.164-sans-plus format) before translation to a national number.

      switch

from: national number

ARCEP, décision 2012-0856 au VI.1

        when $ = @source.match /^3389|^089/
          debug 'Calling number is blocked per ARCEP 05-1085 2.b.1.iii page 14'
          @session.direction = 'trash'
          return @respond '484'

        when $ = @source.match /^33([0-9]+)$/
          @session.ccnq_from_e164 = @source
          @source = "0#{$[1]}"

from: international number

        when $ = @source.match /^([1-9][0-9]+)$/
          @session.ccnq_from_e164 = @source
          @source = "00#{$[1]}"

from: anonymous

        when @source is 'anonymous'
          debug 'Source is anonymous'

        else
          debug 'Invalid source', @source
          return @respond '484 Invalid source'

Update the dialplan
===================

* session.dialplan (string) The dialplan in which a number (source, destination) must be interpreted.

      @session.dialplan = 'national'

      debug 'OK',
        source: @source
        destination: @destination
        diaplan: @session.dialplan
        country: @session.country
      return
