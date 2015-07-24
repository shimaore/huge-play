    seem = require 'seem'
    pkg = require '../../package.json'
    @name = "#{pkg.name}/middleware/client/pre"
    debug = (require 'debug') @name

    @include = seem ->

      @session.direction = @req.variable 'direction'
      @session.profile = @req.variable 'profile'
