    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:cdr"
    debug = (require 'debug') @name
    seem = require 'seem'
    Promise = require 'bluebird'

    @include = ->

Replacement for `esl/src/esl:auto_cleanup`'s `freeswitch_linger` handler.

      @call.once 'cleanup_linger'
      .then seem =>
        debug "CDR: Linger: pausing"
        yield Promise.delay 4000
        debug "CDR: Linger: exit"
        yield @call.exit().catch (error) ->
          debug "exit: #{error}"

      @call.linger()

The `statistics` object is provided by `thinkable-ducks`.

      unless @statistics? and @report?
        debug 'cdr: improper environment'
        return

      @statistics.add 'incoming-calls'
      @report state: 'incoming-call'

      @call.once 'CHANNEL_HANGUP_COMPLETE'
      .then (res) =>
        debug "Channel Hangup Complete", res

* session.cdr_direction (string) original call direction, before it is modified for example into `lcr` or `voicemail`.

        data = res.body
        report =
          direction:      @session.cdr_direction
          duration:       data.variable_mduration
          billable:       data.variable_billmsec
          progress:       data.variable_progressmsec
          answer:         data.variable_answermsec
          wait:           data.variable_waitmsec
          progress_media: data.variable_progress_mediamsec
          flow_bill:      data.variable_flow_billmsec
        debug "CDR: Channel Hangup Complete", report

        @session.cdr_report = report
        @call.emit 'cdr_report', report

        for own k,v of report
          switch k
            when 'direction'
              @statistics.add "direction-#{v}", report.billable
            else
              @statistics.add k, v

Dispatch the event, once using the normal dispatch path (goes to admin), and then on each individual room.

        @report state: 'end', data: report

      return
