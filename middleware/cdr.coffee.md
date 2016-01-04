    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:cdr"
    debug = (require 'debug') @name

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

      @call.linger()
