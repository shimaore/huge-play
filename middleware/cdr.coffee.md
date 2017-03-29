    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:cdr"
    seem = require 'seem'
    Bluebird = require 'bluebird'
    Moment = require 'moment-timezone'


    @include = ->

Replacement for `esl/src/esl:auto_cleanup`'s `freeswitch_linger` handler.

      @call.once 'cleanup_linger'
      .then seem =>
        @debug "CDR: Linger: pausing"
        yield Bluebird.delay 4000
        @debug "CDR: Linger: exit"
        yield @call.exit().catch (error) =>
          @debug.dev "exit: #{error}"

      @call.linger()

      unless @statistics? and @report?
        @debug.dev 'Error: Improper environment'
        return

      @statistics.add 'incoming-calls'
      @report state: 'incoming-call'

      @call.once 'CHANNEL_HANGUP_COMPLETE'
      .then seem (res) =>
        @debug "Channel Hangup Complete"

Invalidate our local copy of `@session.reference_data`.

        yield @get_ref()

* session.cdr_direction (string) original call direction, before it is modified for example into `lcr` or `voicemail`.

        data = res.body
        report =
          direction:      @session.cdr_direction
          emergency:      @session.destination_emergency ? null
          onnet:          @session.destination_onnet ? null
          duration:       data.variable_mduration
          billable:       data.variable_billmsec
          progress:       data.variable_progressmsec
          answer:         data.variable_answermsec
          wait:           data.variable_waitmsec
          progress_media: data.variable_progress_mediamsec
          flow_bill:      data.variable_flow_billmsec

        @session.cdr_report = report
        @call.emit 'cdr_report', report

Update the (existing) call reference data

        @session.call_reference_data.end_time = new Date() .toJSON()
        @session.call_reference_data.report = report
        if @session.timezone?
          @session.call_reference_data.timezone = @session.timezone
          @session.call_reference_data.tz_start_time = Moment @session.call_reference_data.start_time
            .tz @session.timezone
            .format()
          @session.call_reference_data.tz_end_time = Moment @session.call_reference_data.end_time
            .tz @session.timezone
            .format()
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
        yield @save_trace()
        @debug "CDR: Channel Hangup Complete", report
      .catch (error) =>
        @debug "On CHANNEL_HANGUP_COMPLETE, #{error.stack ? error}"

      @debug 'Ready'
      return
