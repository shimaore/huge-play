    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:privacy-FR"
    debug = (require 'debug') @name
    @include = ->

      return unless @session.direction is 'egress'
      return unless @session.dialplan is 'national'
      return unless @session.country is 'fr'
      return if @session.forwarding is true

      debug 'Matching', @destination

      if m = @destination.match /^3651(\d+)$/
        @destination = m[1]
        debug 'Replacing with ', @destination

Add a `Privacy: id` header.

        @action 'privacy', 'number'
