    Debug = require 'debug'
    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:logger"
    debug = Debug @name

    IO = require 'socket.io-client'
    os = require 'os'
    uuidV4 = require 'uuid/v4'

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

    host = process.env.CUDDLY_HOST ? os.hostname()

    @include = ->

### Build identifier

This allows to cross-reference logs and CDRs.

      now = new Date().toJSON()
      uuid = uuidV4()

      @session.logger_stamp = now
      @session.logger_host = host
      @session.logger_uuid = uuid
      id = [host,now,uuid].join '-'
      @session._id = id

### Build debug

      @session.debug ?= []

      make_debug = (e) =>
        (text,args...) =>
          name = @__middleware_name

          data =
            stamp: now
            host: host
            session: id
            application: name
            event: e
            error: text
            data: args

Save in session for later storage via astonishing-competition.

          @session.debug.push data

Debug

          (Debug "#{name}:#{e}") "#{now} #{host} #{id} #{text}", args...

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