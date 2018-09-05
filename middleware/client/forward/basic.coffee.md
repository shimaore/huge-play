    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:forward:basic"
    debug = (require 'tangible') @name
    {hostname} = require 'os'

    @include = ->

      return unless @session?.direction is 'forward'

      @report state:'forward'

      debug 'forwarding on behalf of', @session.endpoint_name
      @session.endpoint = await @cfg.prov.get "endpoint:#{@session.endpoint_name}"
      @session.outbound_route = @session.endpoint.outbound_route
      @session.forwarding = true
      if @cfg.mask_source_on_forward
        @session.source = @source
        @source = @destination
      @destination = @session.destination
      @direction 'egress'
      await @user_tags @session.endpoint.tags

      switch

        when @cfg.answer_on_forward or @session.answer_on_forward
          debug 'answer on forward'
          await @action 'answer' # 200
          await @set sip_wait_for_aleg_ack:false
          @session.wait_for_aleg_ack = false

        when @cfg.preanswer_on_forward or @session.preanswer_on_forward
          debug 'pre_answer on forward'
          await @action 'pre_answer' # 183

        when @cfg.ringready_on_forward or @session.ringready_on_forward
          debug 'ring_ready on forward'
          await @action 'ring_ready' # 180

FIXME the original URI part should be the Request-URI per RFC5806

      await @export
        sip_h_Diversion: "<sip:#{@destination}@#{@cfg.host ? hostname()}>;reason=#{@session.reason}"

      @report
        state: 'pre-forward'
        endpoint: @session.endpoint._id

      debug 'OK',
        'session.outbound_route': @session.outbound_route
        'session.direction': @session.direction
        'session.forwarding': @session.forwarding
        'session.source': @session.source
        'source': @source
        'destination': @destination
      return
