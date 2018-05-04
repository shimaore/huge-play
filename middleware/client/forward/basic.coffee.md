    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:forward:basic"
    debug = (require 'tangible') @name
    {hostname} = require 'os'

    @include = ->

      return unless @session?.direction is 'forward'

      @report state:'forward'

      @debug 'forwarding on behalf of', @session.endpoint_name
      @session.endpoint = await @cfg.prov.get "endpoint:#{@session.endpoint_name}"
      @session.outbound_route = @session.endpoint.outbound_route
      @session.forwarding = true
      if @cfg.mask_source_on_forward
        @session.source = @source
        @source = @destination
      @destination = @session.destination
      @direction 'egress'
      # await @reference.add_in @session.endpoint._id
      await @user_tags @session.endpoint.tags


FIXME the original URI part should be the Request-URI per RFC5806

      await @export
        sip_h_Diversion: "<sip:#{@destination}@#{@cfg.host ? hostname()}>;reason=#{@session.reason}"

      @report
        state: 'pre-forward'
        endpoint: @session.endpoint._id

      @debug 'OK',
        'session.outbound_route': @session.outbound_route
        'session.direction': @session.direction
        'session.forwarding': @session.forwarding
        'session.source': @session.source
        'source': @source
        'destination': @destination
      return
