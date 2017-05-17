    @name = 'huge-play:middleware:trace_in_tangible'

    @server_pre = ->

      if @cfg.update_trace_data?
        @debug.dev 'Another module provided the function, not starting.'
        return

      @cfg.update_trace_data = (data) =>
        @debug.csr 'update_trace_data', data

      @debug 'Ready.'

    @include = ->
