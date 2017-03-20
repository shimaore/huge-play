Register the database we use to store session state.
FIXME: use redis instead.

    @name = 'huge-play:middleware:reference_in_pouchdb'

    seem = require 'seem'
    PouchDB = require 'shimaore-pouchdb'
    uuidV4 = require 'uuid/v4'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    @server_pre = ->

* cfg.session.base (URI) base URI for databases that store automated / complete call records (call-center oriented).

      base = @cfg.session?.base ? @cfg.data?.url

      unless base
        @debug.dev 'No cfg.session.base nor cfg.data.url, references will not be saved.'
        return

* cfg.REFERENCE_DB_PREFIX (string) database-name prefix for references. Default: `reference`.

      db_prefix = @cfg.REFERENCE_DB_PREFIX ?= 'reference'

      if @cfg.get_session_reference_data? or @cfg.update_session_reference_data?
        @debug.dev 'Another module provided the functions, not starting.'
        return

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

Get
---

      @cfg.get_session_reference_data = get_data = (id) ->
        database = name_for_id id

        db = get_db database
        db
          .get id
          .catch -> _id:id

Update
------

      @cfg.update_session_reference_data = save_data = seem (data,tries = 3) =>
        id = data._id
        database = name_for_id id

        db = get_db database
        prev = yield db
          .get id
          .catch -> _id:id

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
