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

      unless @statistics? and @report?
        debug 'Error: Improper environment'
        return

      @statistics.add 'incoming-calls'
      @report state: 'incoming-call'

      @call.once 'CHANNEL_HANGUP_COMPLETE'
      .then seem (res) =>
        debug "Channel Hangup Complete"

* session.cdr_direction (string) original call direction, before it is modified for example into `lcr` or `voicemail`.

        data = res.body
        report =
          direction:      @session.cdr_direction
          emergency:      @session.destination_emergency
          onnet:          @session.destination_onnet
          duration:       data.variable_mduration
          billable:       data.variable_billmsec
          progress:       data.variable_progressmsec
          answer:         data.variable_answermsec
          wait:           data.variable_waitmsec
          progress_media: data.variable_progress_mediamsec
          flow_bill:      data.variable_flow_billmsec

        @session.cdr_report = report
        @call.emit 'cdr_report', report

`call_reference` might not be initialized (e.g. because of malformed context, or because we're running carrier-side)

        if @session.call_reference?
          @session.call_reference_data.end_time = new Date() .toJSON()
          @session.call_reference_data.report = report
          yield @save_ref()

        for own k,v of report
          switch k
            when 'direction'
              @statistics.add "direction-#{v}", report.billable
            when 'emergency'
              @statistics.add "emergency" if v
            when 'onnet'
              @statistics.add "onnet" if v
            else
              @statistics.add k, v

Dispatch the event, once using the normal dispatch path (goes to admin), and then on each individual room.

        @report state: 'end', data: report
        debug "CDR: Channel Hangup Complete", report

      debug 'Ready'
      return
