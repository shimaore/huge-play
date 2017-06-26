    @name = 'huge-play:middleware:trace_in_tangible'

    @notify = ->

      @cfg.statistics.on 'trace', (data) =>
        @debug.csr 'update_trace_data', data

      @debug 'Ready.'

    @include = ->
