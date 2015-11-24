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
      if @cfg.mask_source_on_forward
        @session.source = @source
        @source = @destination
      @destination = @session.destination

FIXME the original URI part should be the Request-URI per RFC5806

      yield @export
        sip_h_Diversion: "<sip:#{@destination}@#{@cfg.host ? hostname()};reason=#{@session.reason}"

      debug 'OK'
      return
