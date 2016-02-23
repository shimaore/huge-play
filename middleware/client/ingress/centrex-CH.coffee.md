    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:centrex-CH"
    debug = (require 'debug') @name
    tones = require '../tones'

    default_internal_ringback = tones.ch.ringback
    default_internal_music = tones.loop tones.ch.waiting

    @include = ->

      return unless @session.direction is 'ingress'
      return unless @session.dialplan is 'centrex'
      return unless @session.country is 'ch'

Add the outside line prefix so that the call can be placed directly.
Note: since we might also come here because we are routing an internal call, skip if the source doesn't need translation.

      @session.centrex_external_line_prefix ?= '9'
      @source = "#{@session.centrex_external_line_prefix}#{@source}" if @source[0] is '0' and not @session.centrex_internal

Also force a normal ringback and no muzak on internal calls.

      if @session.centrex_internal
        @session.ringback = @cfg.internal_ringback ? default_internal_ringback
        @session.music = @cfg.internal_music ? default_internal_music
