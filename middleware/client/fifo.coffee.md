    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:fifo"
    debug = (require 'debug') @name
    Promise = require 'bluebird'
    seem = require 'seem'
    request = require 'superagent'
    Prefix = require 'superagent-prefix'
    qs = require 'querystring'

I'm having issues with FIFO and audio after the calls are connected.

    fifo_works = false

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
        for n in fifo.members
          yield @fifo_add fifo, n
        @cfg.fifos[fifo_name].loaded = true

Ready to send, answer the call.

      debug 'Answer'
      yield @action 'answer'
      call_is_answered = true

      @export
        t38_passthru: false

Basically if the pre_answer we should wait; once the call is answered we won't be getting any more ACK, though.

        sip_wait_for_aleg_ack: not call_is_answered

* session.fifo.announce (string) Name of the FIFO announce file (attachment to the doc:number_domain document).
* session.fifo.music (string) Name of the FIFO music file (attachment to the doc:number_domain document).

      id = "number_domain:#{@session.number_domain}"
      if fifo.announce?
        yield @action 'set', "fifo_announce=#{fifo_uri id, fifo.announce}"
      if fifo.music?
        yield @action 'set', "fifo_music=#{fifo_uri id, fifo.music}"

FIXME: Clear X-CCNQ3 headers + set ccnq_direction etc. (the same way it's done in middleware/client/ingress/post)

      debug 'Send to FIFO'
      if fifo_works
        res = yield @action 'fifo', "#{fifo_name} in"

      else
        yield @set
          continue_on_fail: true
          hangup_after_bridge: false

        if fifo.announce?
          yield @set ringback: fifo_uri id, fifo.announce
        if fifo.music?
          yield @export hold_music: fifo_uri id, fifo.music

        sofias = []
        for member,i in fifo.members
          sofias.push yield @sofia_string member, ["#{k}=#{v}" for own k,v of {
            t38_passthru: false
            leg_timeout: 60
            leg_delay_start: i*2
            progress_timeout: 18
          }]
        debug 'bridge', sofias
        res = yield @action 'bridge', sofias.join ','

      data = res.body
      @session.bridge_data ?= []
      @session.bridge_data.push data
      debug 'Returned from FIFO', data

Available parameters related to transfer are (in the case `bridge` is used):
- `variable_transfer_source` (string)
- `Caller-Transfer-Source` (string)
- `variable_transfer_history` (string or array)

Blind-transfer:
- `variable_transfer_history`: `"1461931135:41606813-d6c0-4bf9-af49-b2017c23ab7c:bl_xfer:endless_playback:http://(nohead=true)127.0.0.1:5714/fifo/number_domain%3Atest.centrex.phone..."`

Attended-transfer:
- `variable_transfer_history`: `[ "1461928571:4edd3fa0-8725-41a4-9322-d1e6b636a913:att_xfer:10@test.centrex.phone../33643482771@178.250.209.67", "1461928571:017ae036-cfdb-4e35-9bd8-0686db3897a0:uuid_br:36093e6f-cc71-484e-8cc7-eb70d42c10be" ]`

The first number in those strings is the timestamp in seconds.
In the case of `uuid_br`, the UUID at the end is the `Other-Leg-Unique-ID`.

      xfer = data.variable_transfer_history
      if xfer?
        debug 'Call was transfered', xfer
        return

      unless fifo_works
        cause = data?.variable_last_bridge_hangup_cause
        cause ?= data?.variable_originate_disposition

        debug "FIFO returned with cause #{cause}"

        if cause in ['NORMAL_CALL_CLEARING', 'SUCCESS', 'NORMAL_CLEARING']
          debug "Successful call when routing FIFO #{fifo_name} through #{sofias.join ','}"
          yield @action 'hangup'
          return

* session.fifo.voicemail (string) If present, the call is redirected to this number's voicemail box if the FIFO failed (for example because no agents are available).

      if fifo.voicemail?
        debug 'Send to voicemail'
        @session.direction = 'voicemail'
        @destination = fifo.voicemail
        yield @validate_local_number()
        return

      debug 'Hangup'
      yield @action 'hangup'

Announce/music download
=======================

This is modelled after the same code in `well-groomed-feast`.

    @web = ->

      prov_prefix = Prefix @cfg.provisioning

      @get '/fifo/:id/:name', ->
        proxy = request
          .use prov_prefix
          .get "#{@params.id}/#{@params.name}"
          .redirects 0

        debug "Proxying #{@cfg.provisioning} #{@params.id}/#{@params.name}"

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
