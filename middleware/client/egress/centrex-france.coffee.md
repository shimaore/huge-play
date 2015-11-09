    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:centrex-france"
    debug = (require 'debug') @name

    @include = ->

      return unless @session.direction is 'egress'
      return unless @session.dialplan is 'centrex'
      return unless @session.country is 'fr'
