    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:national-CH"
    debug = (require 'tangible') @name
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

Only route Fixed Network Services per Numbering Plan for International Carriers http://www.bakom.admin.ch/themen/telekom/00479/00604/index.html?lang=en

        when $ = @destination.match /^41((?:21|22|24|26|27|31|32|33|34|41|43|44|51|52|55|56|58|61|62|71|81|91)[0-9]+)$/
          @session.ccnq_to_e164 = @destination
          @destination = "0#{$[1]}"
          @session.country = 'ch'

        else

Destination _must_ be a Swiss (fixed) number.
Otherwise let it be parsed by another module.

          return

Rewrite source
==============

* session.ccnq_from_e164 (string) The original calling number (in E.164-sans-plus format) before translation to a national number.

      switch

from: national number

        when $ = @source.match /^41([0-9]+)$/
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
