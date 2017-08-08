    @name = 'huge-play:middleware:reference_in:socketio'

    @notify = ->

The `call` event is pre-registered (in spicy-action) on the `calls` bus.
We now use it to transport any data that is call related (at the `reference`-, `call/session`-, or `report`-level).
We also try very hard to mimic the data that will end up in the database, so that event consumers can have a single method for both real-time and database-driven handling of call progress events.

      @register 'queuer', 'calls'
      @register 'call', 'calls'

      @cfg.statistics.on 'report', (report) =>
        switch
          when report._notify and report._queuer
            @socket.emit 'queuer', report

          when report._notify and report.dialplan is 'centrex'
            @socket.emit 'call', report

    @include = ->
