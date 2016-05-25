    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:carrier:egress:send-tough-rate"
    debug = (require 'debug') @name

Compatibility layer between `huge-play` and `tough-rate`: send out a `huge-play` call via `tough-rate`'s call-handler.

    @include = ->

      return unless @session.direction is 'egress'

      {egress_target} = @session.profile_data

      debug 'sendto',
        sip_profile: @session.sip_profile
        destination: @destination
        egress_target: egress_target

      @sendto "sip:#{@destination}@#{egress_target}", @session.sip_profile

Make sute this gets processed by tough-rate.

      @session.direction = 'lcr'
