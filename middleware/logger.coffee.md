    Debug = require 'debug'
    pkg = require '../package.json'
    @name = "#{pkg}:middleware:logger"
    debug = Debug @name

    IO = require 'socket.io-client'
    os = require 'os'

    @server_pre = ->
      url = @cfg.cuddly_url ?= process.env.CUDDLY_URL
      if not url?
        debug 'Missing `cfg.cuddly_url` and CUDDLY_URL'
        return

      @cfg.cuddly_io = IO url

Same semantics as in `cuddly`.

    events = ['dev','ops','csr']

Logging features
----------------

    @include = ->

      host = process.env.CUDDLY_HOST ? os.hostname()

      make_debug = (e) =>
        (text,args...) =>
          now = new Date().toJSON()
          name = @__middleware_name

          data =
            stamp: now
            host: host
            application: name
            event: e
            error: text
            data: args

Save in session for later storage via astonishing-competition.

          @session.debug ?= []
          @session.debug.push data

Debug

          (Debug "#{name}:#{e}") text, args...

Report via cuddly

          if @cfg.cuddly_io? and e in events

            @cfg.cuddly_io
              .emit "report_#{e}", data
              .catch -> yes

          return

Register for `trace` as `@debug`,

      @debug = make_debug 'trace'

and inject `@debug.dev`, `@debug.ops`, `@debug.csr`.

      events.forEach (e) =>
        @debug[e] = make_debug e
      return
