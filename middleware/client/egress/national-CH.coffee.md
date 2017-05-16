    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:national-CH"
    debug = (require 'tangible') @name

    translate_source = (source) ->
      switch

From: national number

        when $ = source.match /^(0|\+41)([1-9][0-9]{8})$/
          return "41#{$[2]}"

From: international number (why??)

        when $ = source.match /^(00|\+)([2-9][0-9]*)$/
          return $[2]

        else
          debug "Cannot translate source #{source}"
          return null

    @include = ->

      return unless @session.direction is 'egress'
      return unless @session.dialplan is 'national'
      return unless @session.country is 'ch'

      debug 'source', @source

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

      patterns = [

geographic, non-geographic, mobile, or service

        { match: /^(0|\+41)([123456789][0-9]{8})$/, now: ($) -> "41#{$[2]}" }

special services

        { match: /^(1[0-9]{2,5})$/, now: ($) -> "41_#{$[1]}" }

international call

        { match: /^(00|\+)([0-9]*)$/, now: ($) -> $[2] }
      ]

      for entry in patterns
        m = @destination.match entry.match
        if m?
          @session.ccnq_to_e164 = entry.now m
          debug 'Found', to_e164: @session.ccnq_to_e164
          return

      debug 'None found', destination: @destination
