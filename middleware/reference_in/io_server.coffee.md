Status: experimental (with thinkable-ducks 7.4.0)

    @name = 'huge-play:reference_io.coffee.md'

    @web = ->
      @cfg.versions[pkg.name] = pkg.version

This allows an external process to connect to this service, and receive event notifications.

      cfg = @cfg
      @on 'connection', ->
        cfg.statistics.on 'report', (report) =>
          @emit 'report', report

    @include = ->
