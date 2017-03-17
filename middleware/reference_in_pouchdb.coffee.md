Register the database we use to store session state.
FIXME: use redis instead.

    seem = require 'seem'
    PouchDB = require 'pouchdb'
    uuidV4 = require 'uuid/v4'
    @name = 'huge-play:middleware:reference_in_pouchdb'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    @server_pre = ->

* cfg.session.db (URI) database used to store automated / complete call records (call-center oriented).

      unless @cfg.session?.base?
        @debug.dev 'Missing cfg.session.base, not starting.'
        return

      if @cfg.get_session_reference_data? or @cfg.update_session_reference_data?
        @debug.dev 'Another module provided the functions, not starting.'
        return

      RemotePouchDB = PouchDB.defaults prefix: @cfg.session.base

* cfg.session.db (URI) The PouchDB URI of the database used to store call reference data. See session.reference_data, session.reference.

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
        database = "reference-#{period}"

      @cfg.get_session_reference_data = get_data = (id) ->

        unless id?
          uuid = new uuidV4()
          period = @cfg.period_of null
          id = "#{period}-#{uuid}"
          @debug 'Assigned new session reference', id

        database = name_for_id id

        db = get_db database
        db
          .get id
          .catch -> _id:id

      @cfg.update_session_reference_data = save_data = seem (data,tries = 3) =>
        prev = yield get_data data._id
        for own k,v of data when k[0] isnt '_'
          prev[k] = v

        database = name_for_id data._id
        db = get_db database
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
