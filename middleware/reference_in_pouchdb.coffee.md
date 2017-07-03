Register the database we use to store session state.
FIXME: use redis instead.

    @name = 'huge-play:middleware:reference_in_pouchdb'
    debug = require('tangible') @name

    seem = require 'seem'
    PouchDB = require 'shimaore-pouchdb'
    LRU = require 'lru-cache'
    uuidV4 = require 'uuid/v4'

    Moment = require 'moment-timezone'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    cache = LRU
      max: 2
      dispose: (key,value) ->
        value?.close?()

    update_doc = (doc,data) ->

Copy the `_in` field (which CouchDB won't accept) in a properly named one.

      if data._in?
        doc.in ?= data._in

Merge tags (but keep them ordered)

      if data.tags?
        doc.tags ?= []
        doc_tags = new Set doc.tags
        for tag in data.tags when not doc_tags.has tag
          doc.tags.push tag

      for own k,v of data when k[0] isnt '_' and k isnt 'tags' and v? and typeof v isnt 'function'
        doc[k] = v

      doc

    @notify = ->

* cfg.session.base (URI) base URI for databases that store automated / complete call records (call-center oriented). Default: cfg.data.url

      base = @cfg.session?.base ? @cfg.data?.url

      unless base
        debug.dev 'No cfg.session.base nor cfg.data.url, references will not be saved.'
        return

      base += '/' unless base.match /\/$/

* cfg.REFERENCE_DB_PREFIX (string) database-name prefix for references. Current value: `reference`.
(Name is fixed because it also appears in `spicy-action/public_proxy`.)

      db_prefix = @cfg.REFERENCE_DB_PREFIX = 'reference'

      get_db = (database) ->
        if cache.has database
          cache.get database
        else
          db = new PouchDB database, prefix: base
          cache.set database, db
          db

      name_for_id = (id) ->
        period = id.substring 0, 7
        database = [db_prefix,period].join '-'

      now = (tz = 'UTC') ->
        Moment().tz(tz).format()

      {host} = @cfg

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

      save_reports = (reports,tries = 3) ->

        timestamp = now()
        reference = reports.find( (r) -> r.reference? )?.reference
        reference ?= timestamp

        database = name_for_id reference
        db = get_db database

        docs = reports.map (report) -> update_doc {}, report

        db
        .bulkDocs docs

In case of failure, retry.
FIXME Properly handle bulkDocs semantics.

        .catch seem (error) =>
          debug "reference error: #{error.stack}", error
          if tries-- > 0
            yield sleep 181
            yield save_reports reports, tries
          else
            call

      @cfg.statistics.on 'reports', save_reports
      @cfg.statistics.on 'report', (report) ->
        save_reports [report]

### Call/Session

A call/session is a single call handled by a FreeSwitch call to `socket`. It is slightly related but not exactly quite what SIP would call a "call".

      save_call = seem (call_data,tries = 3) ->

        # assert call_data.reference?
        # assert call_data.session?

        database = name_for_id call_data.reference

        db = get_db database
        doc = yield db.get(call_data.session).catch -> null

        doc ?=
          _id: call_data.session

        doc = update_doc doc, call_data

        db
        .put doc

In case of success, return the updated document.

        .then ({rev}) ->
          doc._rev = rev
          doc

In case of failure, retry, or return the submitted data.

        .catch seem (error) =>
          debug "update_call_data error: #{error.stack}", error
          if tries-- > 0
            yield sleep 179
            yield save_call call_data, tries
          else
            call_data

      @cfg.statistics.on 'call', save_call

### Reference

A reference is a what a human would call a `call`: a call originated somewhere, as it progresses through menus, redirections, transfers, …
The main purpose of storing the reference-data is to allow data to be propagated along the chain.

      save_data = seem (reference_data,tries = 3) ->
        {_id} = reference_data
        database = name_for_id _id

        db = get_db database
        doc = yield db.get(_id).catch -> null

        doc ?=
          _id: _id

        doc = update_doc doc, reference_data

        db
        .put doc

In case of success, return the updated document.

        .then ({rev}) ->
          doc._rev = rev
          doc

In case of failure, retry, or return the submitted data.

        .catch seem (error) =>
          debug "update_reference_data error: #{error.stack}", error
          if tries-- > 0
            yield sleep 173
            yield save_data reference_data, tries
          else
            reference_data

      debug 'Ready.'

      @cfg.statistics.on 'reference', save_data

    @include = ->
