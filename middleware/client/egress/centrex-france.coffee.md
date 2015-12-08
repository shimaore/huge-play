    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:centrex-france"
    debug = (require 'debug') @name

    @include = ->

      return unless @session.direction is 'egress'
      return unless @session.dialplan is 'centrex'
      return unless @session.country is 'fr'

      switch

Internal call: ring the phone, apply cfa/cfb/cfda/cfnr if applicable.

        when @destination.match /^[1-5]\d{1,2}$/
          debug 'Internal call'
          @session.direction = 'ingress'
          return

External call.

        when m = @destination.match /^9(\d+)$/
          debug 'External call'
          @dialplan = 'national'
          @destination = m[1]
          return

Voicemail.

        when @destination is '*86'
          debug 'Voicemail'
          @session.direction = 'voicemail'
          @destination = 'inbox'
          return
