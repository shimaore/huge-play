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
        integer = (x) ->
          return null if isNaN v = parseInt x
          v
        float = (x) ->
          return null if isNaN v = parseFloat x
          v
        uepoch = (x) ->
          return null if isNaN v = parseInt x
          v//1000

        report =
          direction:      @session.cdr_direction
          emergency:      @session.destination_emergency ? null
          onnet:          @session.destination_onnet ? null
          duration:       integer data.variable_mduration
          billable:       integer data.variable_billmsec
          progress:       integer data.variable_progressmsec
          answer:         integer data.variable_answermsec
          wait:           integer data.variable_waitmsec
          held:           integer data.variable_hold_accum_ms
          progress_media: integer data.variable_progress_mediamsec
          flow_bill:      integer data.variable_flow_billmsec

          start_time:     uepoch data.variable_start_uepoch
          answer_time:    uepoch data.variable_answer_uepoch
          bridge_time:    uepoch data.variable_bridge_uepoch
          progress_time:  uepoch data.variable_progress_uepoch

even-numbered are hold 'on', odd-numbered are hold 'off'

          hold_times:     data.variable_hold_events?.match(/(\d+)/g).map(uepoch) ? []
          end_time:       uepoch data.variable_end_uepoch

          audio_in_packets:     integer data.rtp_audio_in_packet_count
          audio_out_packets:    integer data.rtp_audio_out_packet_count
          skip_packets:         integer data.variable_rtp_audio_in_skip_packet_count
          jitter_packets:       integer data.variable_rtp_audio_in_jitter_packet_count
          jitter_min_variance:  float data.variable_rtp_audio_in_jitter_min_variance
          jitter_max_variance:  float data.variable_rtp_audio_in_jitter_max_variance
          in_mos:               float data.variable_rtp_audio_in_mos

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
