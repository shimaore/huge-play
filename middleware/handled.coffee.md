    @name = 'huge-play:middleware:handled'
    @include = ->
      return unless @session.direction is 'handled'
      d = "sofia/#{@session.sip_profile}/#{@req.variable 'sip_refer_to'}"
      @debug.csr 'transfering call to', d
      @action 'bridge', d
