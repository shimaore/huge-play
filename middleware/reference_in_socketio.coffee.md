    @name = 'huge-play:middleware:reference_in_socketio'

    @notify = ->

The `call` event is pre-registered (in spicy-action) on the `calls` bus.
We now use it to transport any data that is call related (at the `reference`-, `call/session`-, or `report`-level).
We also try very hard to mimic the data that will end up in the database, so that event consumers can have a single method for both real-time and database-driven handling of call progress events.

      @cfg.statistics.on 'reference', (data) =>
        @socket.emit 'call', data

      @cfg.statistics.on 'call', (data) =>
        @socket.emit 'call', data

      @cfg.statistics.on 'report', (data) =>
        @socket.emit 'call', data

      @cfg.statistics.on 'reports', (reports) =>
        reports.forEach (report) ->
          @socket.emit 'call', report

    @include = ->
