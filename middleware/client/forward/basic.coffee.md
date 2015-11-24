    pkg = require '../../../package.json'
    seem = require 'seem'
    @name = "#{pkg.name}:middleware:client:forward:basic"
    debug = (require 'debug') @name
    {hostname} = require 'os'

    @include = seem ->

      return unless @session.direction is 'forward'

      debug 'Ready'
      @session.outbound_route = @session.endpoint.outbound_route
      @session.direction = 'egress'
      @session.forwarding = true
      @destination = @session.destination

      yield @export
        sip_h_Diversion: "<sip:#{@destination}@#{@cfg.host ? hostname()};reason=#{@session.reason}"

      debug 'OK'
      return
