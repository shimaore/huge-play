    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:cdr"
    debug = (require 'tangible') @name
    seem = require 'seem'
    Moment = require 'moment-timezone'

    @include = seem ->

Replacement for `esl/src/esl:auto_cleanup`'s `freeswitch_linger` handler.

      @call.once 'cleanup_linger'
      .then seem =>
        debug "CDR: Linger: pausing"
        yield @sleep 4000
        debug "CDR: Linger: exit"
        yield @call.exit().catch (error) =>
          debug.dev "exit: #{error}"

      yield @call.linger()

      unless @statistics? and @notify?
        debug.dev 'Error: Improper environment'
        return

      @statistics.add 'incoming-calls'
      @notify state: 'incoming-call'

      yield @call.event_json 'CHANNEL_HANGUP_COMPLETE'
      @call.once 'CHANNEL_HANGUP_COMPLETE'
      .then seem (res) =>
        debug "Channel Hangup Complete"

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

        @session.cdr_report = report
        @call.emit 'cdr_report', report

Update the (existing) call data

        @session.call_data.end_time = new Date() .toJSON()
        @session.call_data.report = report
        if @session.timezone?
          @session.call_data.timezone = @session.timezone
          @session.call_data.tz_start_time = Moment @session.call_data.start_time
            .tz @session.timezone
            .format()
          @session.call_data.tz_end_time = Moment @session.call_data.end_time
            .tz @session.timezone
            .format()

        @notify state: 'end', data: report
        yield @save_call()
        yield @save_trace()
        debug "CDR: Channel Hangup Complete", report
      .catch (error) =>
        debug "On CHANNEL_HANGUP_COMPLETE, #{error.stack ? error}"

      debug 'Ready'
      return
