    @name = 'huge-play:middleware:handled'
    @include = ->
      return unless @session.direction is 'handled'
      refer_to = @req.variable 'sip_refer_to'
        .replace /^<(.+)>$/, '$1'
        .replace /^sip:(.+)$/, '$1'
      d = "sofia/#{@session.sip_profile}/#{refer_to}"
      @debug.csr 'transfering call to', d
      @action 'bridge', d
