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

      if @cfg.get_reference_data? or @cfg.update_reference_data?
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

      now = ->
        new Date().toJSON()

Get
---

      @cfg.get_reference_data = get_data = (id) ->
        database = name_for_id id

        db = get_db database
        db
          .get id
          .catch -> _id:id

Update
------

### Report

Normally reports are generated in-call and stored in the `reports` array of the call.
For out-of-call reports we store them in a structure similar to the one used for calls.

      @cfg.save_report = save_report = (o,notification = {},tries = 3) =>
        o.timestamp ?= now()

        doc =
          host: @cfg.host
          reports: [o]

        for own k,v of data when k[0] isnt '_' and v? and typeof v isnt 'function'
          doc[k] ?= v

        db = get_db o.timestamp
        db
        .put doc

In case of failure, retry.

        .catch seem (error) =>
          @debug "reference error: #{error.stack}", error
          if tries-- > 0
            yield sleep 181
            yield save_report o, tries
          else
            call

### Call/Session

A call/session is a single call handled by a FreeSwitch call to `socket`. It is slightly related but not exactly quite what SIP would call a "call".

      @cfg.update_call_data = save_call = (call_data,tries = 3) =>

        call_data.timestamp ?= now()

Merge calls (but keep them ordered)
Note: we use the parameter `call` and completely ignore the values in `data.calls`.

        doc = yield db
          .get call_data.session
          .catch -> _id:call_data.session

        for own k,v of data when k[0] isnt '_' and v? and typeof v isnt 'function'
          doc[k] = v

        db
        .put doc

In case of success, return the updated document.

        .then ({rev}) ->
          doc._rev = rev
          doc

In case of failure, retry, or return the submitted data.

        .catch seem (error) =>
          @debug "update_call_data error: #{error.stack}", error
          if tries-- > 0
            yield sleep 179
            yield save_call call_data, tries
          else
            call_data

### Reference

A reference is a what a human would call a `call`: a call originated somewhere, as it progresses through menus, redirections, transfers, …

      @cfg.update_reference_data = save_data = seem (reference_data,tries = 3) =>
        id = reference_data._id
        database = name_for_id id

        db = get_db database
        doc = yield db
          .get id
          .catch -> _id:id

Merge tags (but keep them ordered)

        doc.tags ?= []
        if reference_data.tags?
          tags = new Set doc.tags
          for tag in reference_data.tags when not tags.has tag
            doc.tags.push tag

Known fields are:
- tags (managed above)
- calls (managed above)
- destination (used by exultant-songs)
- account (set by huge-play, not sure it's actually used)

        for own k,v of reference_data when k[0] isnt '_' and k isnt 'tags' and k isnt 'calls' and v? and typeof v isnt 'function'
          doc[k] = v

        db
        .put doc

In case of success, return the updated document.

        .then ({rev}) ->
          doc._rev = rev
          doc

In case of failure, retry, or return the submitted data.

        .catch seem (error) =>
          @debug "update_reference_data error: #{error.stack}", error
          if tries-- > 0
            yield sleep 173
            yield save_data reference_data, call, tries
          else
            reference_data

      @debug 'Ready.'

    @include = ->
