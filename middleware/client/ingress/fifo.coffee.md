    pkg = require '../../../package'
    @name = "#{pkg.name}:middleware:client:ingress:fifo"
    debug = (require 'debug') @name
    seem = require 'seem'

    @include = seem ->

      return unless @session.direction is 'ingress'

The trigger for this module is the presence of the `fifo` field in the local-number record.

* doc.local_number.fifo (object) If present, ingress calls are handled over to a FIFO application.
* session.number.fifo (object) See doc.local_number.fifo.

      return unless @session.number.fifo?

Prevent further handling by `ingress` middleware.

      @session.direction = 'fifo'

* doc.local_number.fifo.name (string) Name of the FIFO within the numder-domain. Multiple number-domains might have the same queue name.
* doc.local_number.fifo.members (array) List of members, i.e. local-numbers identifiers `<number>@<number-domain>`. The members are dialed without regards to their CFA, .. settings.

      fifo = @session.number.fifo
      fifo_name = "#{@session.number.number_domain}-#{fifo.name}"

      if fifo.members? and not @cfg.fifos[fifo_name]?.loaded
        for member in @session.number.members

Members are on-system agents. We locate the matching local-number and build the dial-string from there.
We only support `endpoint_via` and `cfg.ingress_target` for locating members.

          member_data = yield @cfg.prov.get "number:#{member}"

This is a simplified version of the sofia-string building code found in middleware:client:ingress:send.

          target = member_data.endpoint_via ? cfg.ingress_target
          uri = "sip:#{member_data.number}@#{target}"
          sofia = "sofia/#{@session.sip_profile}/#{uri}"

          debug "Adding member #{member} to #{fifo_name} as #{sofia}"
          yield @api "fifo_member add #{fifo_name} #{sofia}"

        @cfg.fifos ?= {}
        @cfg.fifos[fifo_name] ?= {}
        @cfg.fifos[fifo_name].loaded = true

Ready to send, answer the call.

      yield @action 'answer'

FIXME: conventions for FIFOs audio contents.

      if fifo.announce?
        yield @action 'set', "fifo_announce=#{fifo.announce}"
      if fifo.music?
        yield @action 'set', "fifo_music=#{fifo.music}"

      yield @action 'fifo', "#{fifo_name} in"

FIXME: what kind of call-treatment after the FIFO call is over? How to detect failed FIFO, and what call treatment? Voicemail?

      @action 'hangup'

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
