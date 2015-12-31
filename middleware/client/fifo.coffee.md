    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:fifo"
    debug = (require 'debug') @name
    seem = require 'seem'

    @description = '''
      Handles routing to a given FIFO queue.
    '''
    @include = seem ->

      return unless @session.direction is 'fifo'

      unless @session.fifo?
        debug 'Missing FIFO data'
        return

* session.fifo.members (array) (required) List of members, i.e. local-numbers in the FIFO's number-domain. The members are dialed without regards to their CFA, .. settings.
* session.fifo.name (string) (optional) The name of the FIFO. Defaults to the FIFO index in the doc.number_domain.fifos array. It is interpreted within a given number-domain, so different number-domains might have the same FIFO name.

      fifo = @session.fifo

Build the full fifo name (used inside FreeSwitch) from the short fifo-name and the number-domain.

      fifo_name = "#{@session.number_domain}-#{fifo.name}"

FIXME: Replace with e.g. Redis instead of using cfg for this.

      @cfg.fifos ?= {}
      if fifo.members? and not @cfg.fifos[fifo_name]?.loaded
        @cfg.fifos[fifo_name] ?= {}
        for member in @session.number.members

Members are on-system agents. We locate the matching local-number and build the dial-string from there.
We only support `endpoint_via` and `cfg.ingress_target` for locating members.

          member_data = yield @cfg.prov.get "number:#{member}@#{@session.number_domain}"

This is a simplified version of the sofia-string building code found in middleware:client:ingress:send.

          target = member_data.endpoint_via ? @cfg.ingress_target
          uri = "sip:#{member_data.number}@#{target}"
          sofia = "sofia/#{@session.sip_profile}/#{uri}"

          debug "Adding member #{member} to #{fifo_name} as #{sofia}"
          yield @api "fifo_member add #{fifo_name} #{sofia}"

        @cfg.fifos[fifo_name].loaded = true

Ready to send, answer the call.

      yield @action 'answer'

* session.fifo.announce (string) Location of the FIFO announce.
* session.fifo.music (string) Location of the FIFO music.

      if fifo.announce?
        yield @action 'set', "fifo_announce=#{fifo.announce}"
      if fifo.music?
        yield @action 'set', "fifo_music=#{fifo.music}"

      yield @action 'fifo', "#{fifo_name} in"

* session.fifo.voicemail (string) If present, the call is redirected to this number's voicemail box if the FIFO failed (for example because no agents are available).

      if fifo.voicemail?
        debug 'Send to voicemail'
        @session.direction = 'voicemail'
        @destination = fifo.voicemail
        return

      @action 'hangup'

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
