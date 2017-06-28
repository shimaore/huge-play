    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:fifo"
    debug = (require 'tangible') @name
    seem = require 'seem'
    qs = require 'querystring'

I'm having issues with FIFO and audio after the calls are connected.
TBD: We'll be using some shared state (like Redis) with handlers on ingress/egress.

    @description = '''
      Handles routing to a given ~~FIFO queue~~ACD~~hunt-group.
    '''

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    second = 1000

    @include = seem ->

FIFO handling
=============

      debug 'Starting'

      return unless @session.direction is 'fifo'

      fifo_uri = (id,name) =>
        @prompt.uri 'prov', 'prov', id, name

      unless @session.fifo?
        debug 'Missing FIFO data'
        return

      fifo = @session.fifo

Build the full fifo name (used inside FreeSwitch) from the short fifo-name and the number-domain.

      @tag "fifo:#{fifo.full_name}"

Ready to send, answer the call.

      debug 'Answer'
      yield @action 'answer'
      call_is_answered = true

      yield @export
        t38_passthru: false

Basically if the pre_answer we should wait; once the call is answered we won't be getting any more ACK, though.

        sip_wait_for_aleg_ack: not call_is_answered

* session.fifo.announce (string) Name of the FIFO announce file (attachment to the doc:number_domain document).
* session.fifo.music (string) Name of the FIFO music file (attachment to the doc:number_domain document).

      id = "number_domain:#{@session.number_domain}"

FIXME: Clear X-CCNQ3 headers + set ccnq_direction etc. (the same way it's done in middleware/client/ingress/post)

      debug 'Send to FIFO'
      yield @set
        continue_on_fail: true

      if fifo.announce?
        announce_uri = fifo_uri id, fifo.announce
        yield @set ringback: announce_uri
      if fifo.music?
        music_uri = fifo_uri id, fifo.music
        yield @export hold_music: music_uri

FIXME: This is taken from the centrex-{country} code, but really it should be more generic.

      if @session.ccnq_from_e164?
        @source = "+#{@session.ccnq_from_e164}"

      if fifo.tags?
        for tag in fifo.tags
          @user_tag tag

      if fifo.required_skills?
        for skill in fifo.required_skills
          @tag "skill:#{skill}"

      if typeof fifo.queue is 'string'
        @tag "queue:#{fifo.queue}"

      if fifo.priority?
        @tag "priority:#{fifo.priority}"

If the call-group should use the queuer, then do that.

      if fifo.queue

        @notify state:'queue', name:fifo.full_name, queue: fifo.queue

        {queuer} = @cfg
        Call = @cfg.queuer_Call

        call = new Call
          id: @call.uuid

        yield call.save()
        yield call.set_session @session._id
        yield call.set_tags @session.reference_data?.tags

        if fifo.music?
          yield call.set_music music_uri

        if fifo.announce?
          @action 'endless_playback', announce_uri # async

        yield call.set_remote_number @source
        yield call.set_alert_info @session.alert_info if @session.alert_info?
        yield call.set_reference @session.reference
        yield call.reset 'presenting'
        yield call.del_tag 'bridged'
        yield queuer.queue_ingress_call call

If the call is not processed (no agents are ready), attemp overflow.

Overflow is the weird concept that instead of giving a caller access to all of our capable
agents immediately, we decide to lengthen response time and leave some agents idle, by only
allowing access to them if some conditions are met.
Since we are trying to extend the pool of agents, this is only possible by adding more
desirable queues to a given call. (Adding more required skills would build a smaller pool.)

        call_tags = yield call.tags()
        call_tags = call_tags.filter (tag) -> tag.match /^queue:/

        if call_tags.length is 0
          debug 'no queues, cannot overflow'
          return

        attempt_overflow = seem (suffix) ->
          debug 'attempt overflow', call_tags, suffix
          if yield queuer.ingress_pool.has call
            yield call.add_tags call_tags.map (tag) -> "#{tag}:#{suffix}"
            yield queuer.reevaluate_idle_agents()
            true
          else
            false

Attempt overflow immediately

        unless attempt_overflow 'overflow'
          return

Attempt overflow after a delay

        yield sleep 30*second
        unless attempt_overflow 'overflow:30s'
          return

        yield sleep 30*second
        unless attempt_overflow 'overflow:60s'
          return

        return

Otherwise use the hunt-group behavior.

      @notify state:'group', name:fifo.full_name

      sofias = []

* session.fifo.members (array) (required) List of static members for this hunt-group/ACD/FIFO.
* session.fifo.members[].recipient (string) (required) Local-number in the FIFO's number-domain. The recipients are dialed without regards to their CFA, .. settings.
* session.fifo.members[].delay (integer) Number of seconds to wait before trying to call this recipient, in seconds. Zero or `null` means 'call immediately'. Default: 0.
* session.fifo.members[].progress_timeout (integer) Number of seconds before declaring a recipient unreachable (unable to ring the phone). Default: the progress-timeout of the FIFO.
* session.fifo.members[].timeout (integer) Number of seconds before declaring a recipient unreachable (did not answer), in seconds. Zero means 'wait indefinitely'. Default: the timeout of the FIFO.
* session.fifo.timeout (integer) Default number of seconds before declaring a recipient unreachable (how long to let the recipient's phone ring). Default: zero, meaning 'wait indefinitely'.
* session.fifo.progress_timeout (integer) Default number of seconds before declaring a recipient unreachable (unable to ring the phone). Default: 4.

      fifo_timeout = fifo.timeout ? 0
      fifo_progress_timeout = fifo.progress_timeout ? 4
      for member,i in fifo.members
        # Backward-compatible
        if 'string' is typeof member
          recipient = member
          leg_delay_start = i*5
          leg_progress_timeout = 4
          leg_timeout = 60
        else
          recipient = member.recipient
          leg_delay_start = member.delay ? 0
          leg_progress_timeout = member.progress_timeout ? fifo_progress_timeout
          leg_timeout = member.timeout ? fifo_timeout

        sofias.push yield @sofia_string recipient, ["#{k}=#{v}" for own k,v of {
          t38_passthru: false
          leg_delay_start
          leg_progress_timeout
          leg_timeout
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
        debug 'Call was transferred', xfer
        return

      cause = data?.variable_last_bridge_hangup_cause
      cause ?= data?.variable_originate_disposition

      debug "FIFO returned with cause #{cause}"

      if cause in ['NORMAL_CALL_CLEARING', 'SUCCESS', 'NORMAL_CLEARING']
        debug "Successful call when routing FIFO #{fifo.full_name} through #{sofias.join ','}"
        yield @action 'hangup'
        return

* session.fifo.voicemail (string) If present, the call is redirected to this number's voicemail box if the FIFO failed (for example because no agents are available).
* session.fifo.user_database (string) If present, the call is redirected to this voicemail box if the FIFO failed (for example because no agents are available). Default: use session.fifo.voicemail if present.

      if fifo.voicemail?
        debug 'Send to voicemail'
        @destination = fifo.voicemail
        @direction 'voicemail'
        yield @validate_local_number()
        return

      if fifo.user_database?
        debug 'Send to voicemail (user-database)'
        @destination = 'user-database'
        @session.voicemail_user_database = fifo.user_database
        @session.voicemail_user_id = fifo.full_name
        @direction 'voicemail'
        return

      debug 'Hangup'
      yield @action 'hangup'

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
