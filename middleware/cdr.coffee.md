    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:cdr"
    {debug,foot} = (require 'tangible') @name
    Moment = require 'moment-timezone'

    @include = ->

      call_data = {}

The time we started processing this call.

      call_data.start_time = Date.now()

The call UUID (managed by FreeSwitch).

      call_data.uuid = @call.uuid

A record of the (original, pre-processing) source and destination.

      call_data.source = @source
      call_data.destination = @destination

Replacement for `esl/src/esl:auto_cleanup`'s `freeswitch_linger` handler.

      @call.once 'cleanup_linger', foot =>
        debug "CDR: Linger: pausing"
        await @sleep 4000
        debug "CDR: Linger: exit"
        await @call.exit()
        @end()
        return

      await @call.linger()

      unless @notify?
        debug.dev 'Error: Improper environment'
        return

      await @call.event_json 'CHANNEL_HANGUP_COMPLETE'
      @call.once 'CHANNEL_HANGUP_COMPLETE', foot (res) =>
        debug "Channel Hangup Complete"

* session.cdr_direction (string) original call direction, before it is modified for example into `lcr` or `voicemail`.

        data = res.body
        integer = (x) ->
          return null if isNaN v = parseInt x, 10
          v
        float = (x) ->
          return null if isNaN v = parseFloat x
          v
        uepoch = (x) ->
          return null if isNaN v = parseInt x, 10
          v//1000

        cdr_report =
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

        @session.cdr_report = cdr_report
        @emit 'cdr_report', cdr_report

Update the (existing) call data

        call_data.end_time = Date.now()

        if @session.timezone?
          call_data.timezone = @session.timezone
          call_data.tz_start_time = Moment call_data.start_time
            .tz @session.timezone
            .format()
          call_data.tz_end_time = Moment call_data.end_time
            .tz @session.timezone
            .format()

        await @notify {state:'end', call_data, cdr_report}
        debug "CDR: Channel Hangup Complete", cdr_report
        return

      debug 'Ready'
      return
