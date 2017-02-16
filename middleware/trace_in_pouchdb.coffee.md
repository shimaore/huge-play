Register the database we use to store traces.
FIXME: use some common logging system instead.

    seem = require 'seem'
    PouchDB = require 'pouchdb'
    @name = 'huge-play:middleware:trace_in_pouchdb'
    moment = require 'moment-timezone'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    @server_pre = ->

* cfg.trace.url (URI) Base URI used to store call traces. Default: cfg.data.url

      base = @cfg.trace?.url ? @cfg.data?.url

      unless base
        @debug.dev 'No cfg.trace.url nor cfg.data.url, traces will not be saved.'
        return

* cfg.TRACE_DB_PREFIX (string) database-name prefix for traces. Default: `trace`.

      @cfg.TRACE_DB_PREFIX = 'trace'

      if @cfg.update_trace_data?
        @debug.dev 'Another module provided the function, not starting.'
        return

      trace_period = null
      db = null

      @cfg.update_trace_data = save_data = seem (data,tries = 3) =>
        new_trace_period = new Date().toJSON()[0..6]

        if trace_period isnt new_trace_period
          trace_period = new_trace_period
          trace_database = [@cfg.TRACE_DB_PREFIX,trace_period].join '-'
          db?.close()
          db = new PouchDB "#{base}/#{trace_database}"

        prev = yield get_data data._id
        for own k,v of data when k[0] isnt '_' and typeof v isnt 'function'
          prev[k] = v
        {rev} = yield db
          .put prev
          .catch seem (error) =>
            @debug "error: #{error.stack ? error}"
            if tries-- > 0
              yield sleep 173
              yield save_data data, tries
            rev: data._rev
        data._rev = rev
        return

      @debug 'Ready.'

    @include = ->
