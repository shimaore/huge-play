Register the database we use to store traces.
FIXME: use some common logging system instead.

    @name = 'huge-play:middleware:trace_in_pouchdb'

    seem = require 'seem'
    PouchDB = require 'shimaore-pouchdb'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    @server_pre = ->

* cfg.trace.url (URI) Base URI used to store call traces. Default: cfg.data.url

      base = @cfg.trace?.url ? @cfg.data?.url

      unless base
        @debug.dev 'No cfg.trace.url nor cfg.data.url, traces will not be saved.'
        return

      base += '/' unless base.match /\/$/

* cfg.TRACE_DB_PREFIX (string) database-name prefix for traces. Current value: `trace`.
(Name is fixed because it also appears in `spicy-action/public_proxy`.)

      db_prefix = @cfg.TRACE_DB_PREFIX = 'trace'

      RemotePouchDB = PouchDB.defaults prefix: base

      current_db_name = null
      current_db = null

      get_db = (database) ->
        if current_db_name is database
          current_db
        else
          current_db?.close()
          current_db_name = database
          current_db = new RemotePouchDB current_db_name

      name_for_id = (id) ->
        period = id[0...7]
        database = [db_prefix,period].join '-'

Update
------

      save_data = seem (data,tries = 3) =>
        id = data._id
        database = name_for_id data.logger_stamp

        db = get_db database
        prev = yield db
          .get id
          .catch -> _id:id

        for own k,v of data when k[0] isnt '_' and typeof v isnt 'function'
          prev[k] = v

        {rev} = yield db
          .put prev
          .catch seem (error) =>
            @debug "trace error: #{error.stack}", error
            if tries-- > 0
              yield sleep 173
              yield save_data data, tries
            rev: data._rev
        data._rev = rev
        return

      @cfg.statistics.on 'trace', save_data

      @debug 'Ready.'

    @include = ->
