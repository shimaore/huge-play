    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:fifo"
    debug = (require 'debug') @name
    Promise = require 'bluebird'
    seem = require 'seem'
    request = require 'request'
    qs = require 'querystring'

    @description = '''
      Handles routing to a given FIFO queue.
    '''
    @include = seem ->

FIFO handling
=============

      debug 'Starting'

      return unless @session.direction is 'fifo'

      fifo_uri = (id,name) =>
        host = @cfg.web.host ? '127.0.0.1'
        port = @cfg.web.port
        id = qs.escape id
        name = qs.escape name
        "http://(nohead=true)#{host}:#{port}/fifo/#{id}/#{name}"

      unless @session.fifo?
        debug 'Missing FIFO data'
        return

* session.fifo.members (array) (required) List of members, i.e. local-numbers in the FIFO's number-domain. The members are dialed without regards to their CFA, .. settings.
* session.fifo.name (string) (optional) The name of the FIFO. Defaults to the FIFO index in the doc.number_domain.fifos array. It is interpreted within a given number-domain, so different number-domains might have the same FIFO name.

      fifo = @session.fifo

Build the full fifo name (used inside FreeSwitch) from the short fifo-name and the number-domain.

      fifo_name = @fifo_name fifo

FIXME: Replace with e.g. Redis instead of using cfg for this.

      @cfg.fifos ?= {}
      @cfg.fifos[fifo_name] ?= {}
      debug "FIFO status for #{fifo_name}", @cfg.fifos[fifo_name]

      if fifo.members? and not @cfg.fifos[fifo_name].loaded
        debug 'Loading fifo members', fifo.members
        yield Promise.all fifo.members.map (n) => @fifo_add fifo, n
        @cfg.fifos[fifo_name].loaded = true

Ready to send, answer the call.

      debug 'Answer'
      yield @action 'answer'

* session.fifo.announce (string) Name of the FIFO announce file (attachment to the doc:number_domain document).
* session.fifo.music (string) Name of the FIFO music file (attachment to the doc:number_domain document).

      id = "number_domain:#{@session.number_domain}"
      if fifo.announce?
        yield @action 'set', "fifo_announce=#{fifo_uri id, fifo.announce}"
      if fifo.music?
        yield @action 'set', "fifo_music=#{fifo_uri id, fifo.music}"

      debug 'Send to FIFO'
      yield @action 'fifo', "#{fifo_name} in"

* session.fifo.voicemail (string) If present, the call is redirected to this number's voicemail box if the FIFO failed (for example because no agents are available).

      if fifo.voicemail?
        debug 'Send to voicemail'
        @session.direction = 'voicemail'
        @destination = fifo.voicemail
        return

      debug 'Hangup'
      yield @action 'hangup'

Announce/music download
=======================

This is modelled after the same code in `well-groomed-feast`.

    @web = ->

      @get '/fifo/:id/:name', ->
        proxy = request.get
          baseUrl: @cfg.provisioning
          uri: "#{@params.id}/#{@params.name}"
          followRedirects: false
          maxRedirects: 0

        debug "Proxying #{@cfg.provisioning} #{@params.id}/#{@params.name}"

        @request.pipe proxy
        .on 'error', (error) =>
          @next "Got #{error}"
          return
        proxy.pipe @response
        return

Backup notes
------------

FreeSwitch functions to use:

`fifo_member` -- API to load members (from DB)

`fifo` -- application
  -- `<queue> in <exit-msg> <moh>` -- for callers
  -- `<queue> out wait` for consumers (off-hook agents)
  -- `<queue> out nowait <found> <moh>` -- for agents that call into the queue to pick one customer
Not: when calling with 'out', there may be multiple 'queue' names separated by commas.

- member: agent will be called when a caller comes in
  log-in = fifo_member add
  log-out = fifo_member del
- consumer: agent calls "into the queue" and is put on hold until a caller comes in (off-hook agent)
  fifo_consumer_exit_key '*' disconnects a caller
  '0' puts the caller on/off hold
  fifo_consumer_wrapup_sound
  fifo_consumer_wrapup_key
  fifo_consumer_wrapup_time
- nowait consumer: agents calls "into the queue" and receives one call

https://wiki.freeswitch.org/wiki/Simple_call_center_using_mod_fifo
https://wiki.freeswitch.org/wiki/Mod_fifo

Vars:

fifo_announce
fifo_caller_consumer_import
