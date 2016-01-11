    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:cdr"
    debug = (require 'debug') @name
    seem = require 'seem'
    Promise = require 'bluebird'

    @include = ->

      @call.once 'CHANNEL_HANGUP_COMPLETE'
      .then (res) =>
        debug "CDR: Channel Hangup Complete", res

        data = res.body
        report =
          duration:       data.variable_mduration
          billable:       data.variable_billmsec
          progress:       data.variable_progressmsec
          answer:         data.variable_answermsec
          wait:           data.variable_waitmsec
          progress_media: data.variable_progress_mediamsec
          flow_bill:      data.variable_flow_billmsec
        debug "CDR: Channel Hangup Complete", report

The `statistics` object is provided by `thinkable-ducks`.

        for own k,v of report
          @statistics.add k, v

        @statistics.emit 'call',
          state: 'end'
          call: @call.uuid
          source: @source
          destination: @destination
          data: report

Replacement for `esl/src/esl:auto_cleanup`'s `freeswitch_linger` handler.

      @call.once 'autocleanup_linger'
      .then seem =>
        debug "CDR: Linger: pausing"
        yield Promise.delay 4000
        debug "CDR: Linger: exit"
        yield @call.exit().catch (error) ->
          debug "exit: #{error}"

      @call.linger()
