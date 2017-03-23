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

* cfg.session.base (URI) base URI for databases that store automated / complete call records (call-center oriented). Default: cfg.data.url

      base = @cfg.session?.base ? @cfg.data?.url

      unless base
        @debug.dev 'No cfg.session.base nor cfg.data.url, references will not be saved.'
        return

      base += '/' unless base.match /\/$/

* cfg.REFERENCE_DB_PREFIX (string) database-name prefix for references. Current value: `reference`.
(Name is fixed because it also appears in `spicy-action/public_proxy`.)

      db_prefix = @cfg.REFERENCE_DB_PREFIX = 'reference'

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

      @cfg.update_session_reference_data = save_data = seem (data,call,tries = 3) =>
        id = data._id
        database = name_for_id id

        db = get_db database
        doc = yield db
          .get id
          .catch -> _id:id

Merge tags (but keep them ordered)

        doc.tags ?= []
        tags = new Set doc.tags
        for tag in data.tags when not tags.has tag
          doc.tags.push tag

Merge calls (but keep them ordered)
Note: we use the parameter `call` and completely ignore the values in `data.calls`.

        doc.calls ?= []
        for c, i in doc.calls when c.session is call.session
          doc.calls[i] = call
          call = null
        if call?
          doc.calls.push call

Known fields are:
- tags (managed above)
- calls (managed above)
- destination (used by exultant-songs)
- account (set by huge-play, not sure it's actually used)

        for own k,v of data when k[0] isnt '_' and k isnt 'tags' and k isnt 'calls' and v? and typeof v isnt 'function'
          doc[k] = v

        db
        .put doc

In case of success, return the updated document.

        .then ({rev}) ->
          doc._rev = rev
          doc

In case of failure, retry, or return the submitted data.

        .catch seem (error) =>
          @debug "reference error: #{error.stack}", error
          if tries-- > 0
            yield sleep 173
            yield save_data data, call, tries
          else
            data

      @debug 'Ready.'

    @include = ->
