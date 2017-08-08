Status: experimental

Sends out messages to a remote socket.io server for aggregation.

    @name = 'huge-play:reference_in:io_client'

    io = require 'socket.io-client'

    @server_post = ->

      cfg = @cfg
      return unless cfg.capable?

      socket = io cfg.capable

      socket.on 'connect', ->

        cfg.statistics.on 'report', (report) ->
          socket.emit 'report', report

      socket.on 'connect_error', ->
      socket.on 'connect_timeout', ->
      socket.on 'error', ->
      socket.on 'disconnect', ->
      socket.on 'reconnect', ->
      socket.on 'reconnect_attempt', ->
      socket.on 'reconnecting', ->
      socket.on 'reconnect_error', ->

    @include = ->
