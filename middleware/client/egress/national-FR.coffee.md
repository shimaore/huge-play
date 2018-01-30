Internally we route french numbers like any international number,
e.g. 33+national number (without the "0" or "E" prefix)
however in France the dialing plan cannot be readily mapped into
the international numbering plan because special codes, etc. in the
national dialing plan do interfere with national prefixes.
(For example, 112 and 3615 are prefixes for geographic numbers.)

On the other hand, in order to be routable all output numbers must
contain digits. We use `_` (underscore) to prefix special numbers.

For example:
* 3615 (french national dialing plan) is mapped to 33_3615 (international numbering plan)
* 112 (french national dialing plan) is mapped to 33_112 (international numbering plan)

See http://www.arcep.fr/index.php?id=interactivenumeros

    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:national-FR"
    debug = (require 'tangible') @name

    translate_source = (source) ->
      switch

From: national number

        when $ = source.match /^(0|\+33)([123456789][0-9]{8})$/
          return "33#{$[2]}"

From: international number (why??)

        when $ = source.match /^(00|\+)([2-9][0-9]*)$/
          return $[2]

        else
          debug "Cannot translate source #{source}"
          return null

    @include = ->

      return unless @session?.direction is 'egress'
      return unless @session.dialplan is 'national'
      return unless @session.country is 'fr'

      @debug 'source', @source

Verify that the caller-id follows the proper format
---------------------------------------------------

      new_source = translate_source @source
      if new_source?
        @session.ccnq_from_e164 = new_source

      if @session.asserted?
        new_asserted = translate_source @session.asserted
        if new_asserted?
          @session.asserted = new_asserted

Verify that the called number follows the proper format
-------------------------------------------------------

International numbers embedded inside the National numbering plan:
decision ARCEP 06-0720

      patterns = [

ARCEP 06-0720

fixes mayotte, réunion, territoires océan indien

        { match: /^(0|\+33)(26[29].*)$/, now: ($) -> "262#{$[2]}" }

mobiles mayotte

        { match: /^(0|\+33)(639.*)$/, now: ($) -> "262#{$[2]}" }

decision ARCEP 06-0535 + 00-0536

mobiles-guadeloupe

        { match: /^(0|\+33)(69[01].*)$/, now: ($) -> "590#{$[2]}" }

mobiles-reunion

        { match: /^(0|\+33)(69[23].*)$/, now: ($) -> "262#{$[2]}" }

mobiles-guyane

        { match: /^(0|\+33)(694.*)$/, now: ($) -> "594#{$[2]}" }

mobiles-martinique

        { match: /^(0|\+33)(69[67].*)$/, now: ($) -> "596#{$[2]}" }

other, fixes
fixes-guadeloupe

        { match: /^(0|\+33)(590.*)$/, now: ($) -> "590#{$[2]}" }

fixes-reunion

        { match: /^(0|\+33)(262.*)$/, now: ($) -> "262#{$[2]}" }

fixes-guyane

        { match: /^(0|\+33)(594.*)$/, now: ($) -> "594#{$[2]}" }

fixes-martinique

        { match: /^(0|\+33)(596.*)$/, now: ($) -> "596#{$[2]}" }

actually fixes and mobiles are mixed. Also the international dialplan is different, see http://www.itu.int/oth/T02020000B2/en
fixes-stpierre

        { match: /^(0|\+33)(508.*)$/, now: ($) -> $[2] }

ARCEP 04-0847
nongeo-guadeloupe

        { match: /^(0|\+33)(876[01].*|976[018])$/, now: ($) -> "590#{$[2]}" }

nongeo-reunion

        { match: /^(0|\+33)(876[23].*|976[239])$/, now: ($) -> "262#{$2}" }

nongeo-guyane

        { match: /^(0|\+33)(876[4].*|976[45])$/, now: ($) -> "594#{$[2]}" }

nongeo-martinique

        { match: /^(0|\+33)(876[67].*|976[67])$/, now: ($) -> "596#{$[2]}" }

geographic, non-geographic, mobile, or service

        { match: /^(0|\+33)([123456789][0-9]{8})$/, now: ($) -> "33#{$[2]}" }

special services

        { match: /^(1[0-9]{1,5}|3[0-9]{3})$/, now: ($) -> "33_#{$[1]}" }

international call

        { match: /^(00|\+)([0-9]*)$/, now: ($) -> $[2] }
      ]

      for entry in patterns
        m = @destination.match entry.match
        if m?
          @session.ccnq_to_e164 = entry.now m
          @debug 'Found', to_e164: @session.ccnq_to_e164
          return

      @debug 'None found', destination: @destination
