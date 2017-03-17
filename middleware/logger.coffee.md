    Debug = require 'debug'
    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:logger"
    debug = Debug @name

    IO = require 'socket.io-client'
    os = require 'os'
    uuidV4 = require 'uuid/v4'

Same semantics as in `cuddly`.

    events = ['dev','ops','csr']

    host = process.env.CUDDLY_HOST ? os.hostname()

Config, Server-pre
==================

    non_call_logger = ->

Connect to cuddly server

      url = @cfg.cuddly_url ?= process.env.CUDDLY_URL
      if url?
        @cfg.cuddly_io = IO url
      else
        debug 'Missing both `cfg.cuddly_url` and CUDDLY_URL'

Insert `@debug`.

      now = new Date().toJSON()

      make_debug = (e) =>
        (text,args...) =>
          name = @__middleware_name

          data =
            stamp: now
            host: host
            application: name
            event: e
            error: text
            data: args

Debug

          (Debug "#{name}:#{e}") "#{now} #{host} #{text}", args...

Report via cuddly

          if @cfg.cuddly_io? and e in events

            @cfg.cuddly_io.emit "report_#{e}", data

          return

Register for `trace` as `@debug`,

      @debug = make_debug 'trace'

and inject `@debug.dev`, `@debug.ops`, `@debug.csr`.

      events.forEach (e) =>
        @debug[e] = make_debug e
      return

    @config = non_call_logger
    @server_pre = non_call_logger
    @web = non_call_logger
    @notify = non_call_logger

Per-call Logging features
=========================

    Now = -> new Date().toJSON()

    @include = ->

### Build identifier

This allows to cross-reference logs and CDRs.

      now = Now()
      uuid = uuidV4()

      @session.logger_stamp = now
      @session.logger_host = host
      @session.logger_uuid = uuid
      id = [host,now,uuid].join '-'
      @session._id = id

* session._id (string) A unique identifier for this session/call.

### Build debug

FIXME: This just leads to high memory usage.

      # @session.debug ?= []

      make_debug = (e) =>
        (text,args...) =>

FIXME This does not work in callbacks.

          name = @__middleware_name

          data =
            stamp: Now()
            host: host
            session: id
            application: name
            event: e
            msg: text
            data: args

Save in session for later storage via astonishing-competition.

          @session.debug?.push data

Debug

          if @cfg.dev_logger
            (Debug "#{name}:#{e}") "#{now} #{host} #{text}", args...

Report via cuddly

          if @cfg.cuddly_io? and e in events

            @cfg.cuddly_io.emit "report_#{e}", data

          return

Register for `debug` as `@debug`,

      @debug = make_debug 'debug'

and inject `@debug.dev`, `@debug.ops`, `@debug.csr`.

      events.forEach (e) =>
        @debug[e] = make_debug e
      return
