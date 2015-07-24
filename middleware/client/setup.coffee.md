    pkg = require '../../package.json'
    @name = "#{pkg.name}:middleware:client:setup"
    debug = (require 'debug') @name

    @include = ->

      @session.direction = @req.variable 'direction'
      @session.profile = @req.variable 'profile'
