    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:prompt"
    debug = (require 'tangible') @name
    Nimble = require 'nimble-direction'
    CouchDB = require 'most-couchdb'

    request = require 'request'
    qs = require 'querystring'

Use `mod_httpapi` to support URLs.

    @include = ->

      prompt = {}

`record`
========

Record using the given file or uri.

https://wiki.freeswitch.org/wiki/Misc._Dialplan_Tools_record

      prompt.record = (file,time_limit = 300) =>
        debug 'record', {file,time_limit}
        silence_thresh = 20
        silence_hits = 3
        await @action 'set', 'playback_terminators=any'
        await @action 'gentones', '%(500,0,800)'
        res = await @action 'record', [
            file
            time_limit
            silence_thresh
            silence_hits
          ].join ' '
        body = res?.body ? {}

The documentation says:
- record_ms
- record_samples
- playback_terminator_used

        duration = body.variable_record_seconds
        debug 'record', {duration}
        duration

`play_and_get_digits`
=====================

Simple wrapper for FreeSwitch's `play_and_get_digits`.

Required options:
- `min`
- `max`
- `timeout`
- `file`
- `var_name`
- `regexp`
- `digit_timeout`


https://wiki.freeswitch.org/wiki/Misc._Dialplan_Tools_play_and_get_digits

      prompt.play_and_get_digits = (o) =>
        debug 'play_and_get_digits', o
        @action 'play_and_get_digits', [
          o.min
          o.max
          o.tries ? 1
          o.timeout
          o.terminators ? '#'
          o.file
          o.invalid_file ? 'silence_stream://250'
          o.var_name
          o.regexp
          o.digit_timeout
          o.transfer_on_failure ? ''
        ].join ' '

`play`
======

Play a file and optionnally record a single digit.
Promise resolves into the selected digit or `null`.

      prompt.play = (file,o={}) ->
        o.file = file
        o.min ?= 1
        o.max ?= 1
        o.timeout ?= 1000
        o.var_name ?= 'choice'
        o.regexp ?= '\\d'
        o.digit_timeout ?= 1000
        res = await prompt.play_and_get_digits o
        body = res?.body ? {}
        name = "variable_#{o.var_name}"
        debug "Got #{body[name]} for #{name}"
        body[name] ? null

`get_choice`
========

Play a file and optionnaly record a single digit.
Promise resolves into the selected digit or `null`.

      prompt.get_choice = (file,o={}) ->
        o.timeout ?= 15000
        o.digit_timeout ?= 3000
        prompt.play file, o

`get_number`
============

Asks for a number.
Promise resolves into the number or `null`.

      prompt.get_number = (o={}) ->
        o.file ?= 'phrase:voicemail_enter_id:#'
        o.invalid_file ?= "phrase:'voicemail_fail_auth'"
        o.min ?= 1
        o.max ?= 16
        o.var_name ?= 'number'
        o.regexp ?= '\\d+'
        o.digit_timeout ?= 3000
        prompt.get_choice o.file, o

`get_pin`
=========

Asks for a PIN.
Promise resolves into the PIN or `null`.

      prompt.get_pin = (o={}) ->
        o.file ?= 'phrase:voicemail_enter_pass:#'
        o.min ?= 4
        o.max ?= 16
        o.var_name ?= 'pin'
        prompt.get_number o

`get_new_pin`
=============

Asks for a new PIN.
Promise resolves into the new PIN or `null`.

      prompt.get_new_pin = (o={}) ->
        o.var_name ?= 'new_pin'
        o.invalid_file = 'silence_stream://250'
        prompt.get_pin o

      prompt.goodbye = =>
        debug 'goodbye'
        await prompt.phrase 'voicemail_goodbye'
        await @action 'hangup'
        debug 'goodbye done'

      prompt.phrase = (phrase) =>
        debug 'phrase'
        await @action 'phrase', phrase

      prompt.error = (id) ->
        debug 'error', {id}
        await prompt.phrase "spell,#{id}" if id?
        await prompt.goodbye()
        Promise.reject new Error "error #{id}"

`uri`
-----

Provide a URI to access the web services (attachment upload/download) defined below.
Note that since FreeSwitch has trouble with query parameters (`Invalid file format [wav?rev=…]`) the revision number has to be provided as part of the path.

      prompt.uri = (domain,db,id,file,rev) =>
        host = @cfg.web.host ? '127.0.0.1'
        port = @cfg.web.port

        domain = qs.escape domain
        db = qs.escape db
        id = qs.escape id
        rev = qs.escape rev ? 'no-rev'
        file = qs.escape file
        path = "/#{domain}/#{db}/#{id}/#{rev}/#{file}"

        "http://#{host}:#{port}#{path}"

      @prompt = prompt
      return

Attachment upload/download
==========================

    @web = ->
      @cfg.versions[pkg.name] = pkg.version

      cfg = @cfg

      @translators = translators =

A translator for user databases.

        'user-db': (db,id,file) =>
          db = qs.escape db
          id = qs.escape id
          file = qs.escape file
          base: cfg.userdb_base_uri
          uri: "/#{db}/#{id}/#{file}"

A translator for the local provisioning database (the `db` database name is ignored).

        'prov': (db,id,file) =>
          id = qs.escape id
          file = qs.escape file
          base: (Nimble cfg).provisioning
          uri: "#{id}/#{file}"

        'master-prov': (db,id,file) =>
          id = qs.escape id
          file = qs.escape file
          masters = (Nimble cfg).prov_master_admin
          if masters?
            if typeof masters is 'string'
              masters = [masters]
          base: masters[0] # fixme: pick one at random
          uri: "#{id}/#{file}"

      @get '/:domain/:db/:id/:rev/:file', ->
        translator = translators[@params.domain]
        unless translator?
          @next 'Invalid domain'
          return

        {base,uri} = translator @params.db, @params.id, @params.file

        debug 'web:get', base, uri

        proxy = request.get
          baseUrl: base
          uri: uri
          followRedirects: false
          maxRedirects: 0

        @request.pipe proxy
         .on 'error', (error) =>
          debug.ops "GET #{uri} : #{error}"
          @next "GET #{uri} : #{error}"
          return
        proxy.pipe @response
        return

      @put '/:domain/:db/:id/:rev/:file', ->
        translator = translators[@params.domain]
        unless translator?
          @next 'Invalid domain'
          return

        {base,uri} = translator @params.db, @params.id, @params.file

        debug 'web:put', base, uri

        proxy = request.put
          baseUrl: base
          uri: uri
          qs:
            rev: @params.rev
          followRedirects: false
          maxRedirects: 0
          timeout: 120

        @request.pipe proxy
        .on 'error', (error) =>
          debug.ops "GET #{uri} rev #{@params.rev} : #{error.stack ? error}"
          try @res.end()
          return
        proxy.pipe @response
        return
