    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:prompt"
    debug = (require 'debug') @name

    request = require 'request'
    qs = require 'querystring'
    seem = require 'seem'

    @web = ->
      @cfg.versions[pkg.name] = pkg.version

Use `mod_httpapi` to support URLs.

    @include = ->

      prompt = {}

`record`
========

Record using the given file or uri.

https://wiki.freeswitch.org/wiki/Misc._Dialplan_Tools_record

      prompt.record = seem (file,time_limit = 300) =>
        debug 'record', {file,time_limit}
        silence_thresh = 20
        silence_hits = 3
        yield @action 'set', 'playback_terminators=any'
        yield @action 'gentones', '%(500,0,800)'
        {body} = yield @action 'record', [
            file
            time_limit
            silence_thresh
            silence_hits
          ].join ' '

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

      prompt.play = seem (file,o={}) ->
        o.file = file
        o.min ?= 1
        o.max ?= 1
        o.timeout ?= 1000
        o.var_name ?= 'choice'
        o.regexp ?= '\\d'
        o.digit_timeout ?= 1000
        {body} = yield prompt.play_and_get_digits o
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

      prompt.goodbye = seem =>
        debug 'goodbye'
        yield prompt.phrase 'voicemail_goodbye'
        yield @action 'hangup'
        debug 'goodbye done'

      prompt.phrase = seem (phrase) =>
        debug 'phrase'
        yield @action 'phrase', phrase

      prompt.error = seem (id) ->
        debug 'error', {id}
        yield prompt.phrase "spell,#{id}" if id?
        yield prompt.goodbye()
        Promise.reject new Error "error #{id}"

`uri`
-----

Provide a URI to access the web services (attachment upload/download) defined below.

      prompt.uri = (path,rev,simple) ->
        host = ctx.cfg.web.host ? '127.0.0.1'
        port = ctx.cfg.web.port
        if rev?
          rev = qs.escape rev
          "http://#{host}:#{port}#{path}?rev=#{rev}"
        else
          if simple
            "http://#{host}:#{port}#{path}"
          else
            "http://(nohead=true)#{host}:#{port}#{path}"

      @prompt = prompt
      return

Attachment upload/download
==========================

    @web = ->

      @proxy_get = (base,uri) ->
        proxy = request.get
          baseUrl: base
          uri: uri
          followRedirects: false
          maxRedirects: 0

        @request.pipe proxy
         .on 'error', (error) =>
          debug "GET #{uri} : #{error}"
          @next "GET #{uri} : #{error}"
          return
        proxy.pipe @response
        return

      @proxy_put = (base,uri,rev) ->
        proxy = request.put
          baseUrl: base
          uri: uri
          qs:
            rev: rev
          followRedirects: false
          maxRedirects: 0
          timeout: 120

        @request.pipe proxy
        .on 'error', (error) =>
          debug "GET #{uri} rev #{@params.rev} : #{error.stack ? error}"
          try @res.end()
          return
        proxy.pipe @response
        return
