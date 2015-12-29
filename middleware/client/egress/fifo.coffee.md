    pkg = require '../../../package'
    @name = "#{pkg.name}:middleware:client:egress:fifo"
    debug = (require 'debug') @name
    seem = require 'seem'

    @include = seem ->
      return unless @session.direction is 'egress'
      return unless @session.dialplan is 'centrex'

      switch @destination

        when '811'
          debug 'FIFO: log in'
          yield @action 'answer'
          yield @api "fifo_member add #{fifo.name} {fifo_member_wait=nowait}#{sofia}"
          yield @action 'playback', 'ivr/ivr-you_are_now_logged_in.wav'
          yield @action 'hangup'
          return

        when '819'
          debug 'FIFO: log out'
          yield @action 'answer'
          yield @api "fifo_member add #{fifo.name} {fifo_member_wait=nowait}#{sofia}"
          yield @action 'playback', 'ivr/ivr-you_are_now_logged_out.wav'
          yield @action 'hangup'
          return
