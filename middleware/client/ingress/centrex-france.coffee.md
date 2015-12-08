    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:centrex-france"
    debug = (require 'debug') @name

    default_internal_ringback = '%(1500,3500,440)'
    default_internal_music = 'tone_stream://%(300,10000,440);loops=-1'

    @include = ->

      return unless @session.direction is 'ingress'
      return unless @session.dialplan is 'centrex'
      return unless @session.country is 'fr'

Add the outside line prefix so that the call can be placed directly.

      @source = "9#{@source}"

Also force a normal ringback and no muzak.

      @session.ringback = @cfg.internal_ringback ? default_internal_ringback
      @session.music = @cfg.internal_music ? default_internal_music
