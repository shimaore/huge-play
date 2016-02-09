    pkg = require '../../../package'
    @name = "#{pkg.name}:middleware:client:egress:fifo"
    debug = (require 'debug') @name
    seem = require 'seem'

    @include = seem ->
      return unless @session.direction is 'egress'
      return unless @session.dialplan is 'centrex'

      unless @session.number_domain
        debug 'No number domain'
        return

      return unless m = @destination.match /^8(\d+)(\d)$/

The destination matched.

      fifo_number = parseInt m[1]

      ACTION_ROUTE = '0'
      ACTION_LOGIN = '1'
      ACTION_LOGOUT = '9'
      action = m[2]

      return unless Number.isInteger fifo_number

      @session.number_domain_data ?= yield @cfg.prov
        .get "number_domain:#{@session.number_domain}"
        .catch (error) =>
          debug "number_domain #{number_domain}: #{error}"
          {}

      unless @session.number_domain_data.fifos?
        debug 'No FIFOs'
        return

      fifo = @session.number_domain_data.fifos[fifo_number]

      unless fifo?
        debug "Missing FIFO in number-domain", {
          number_domain: @session.number_domain
          fifo_number
        }
        return

      fifo.name ?= "#{fifo_number}"

      switch action

Route to FIFO: this should look similar to what is done in client/ingress/fifo.

        when ACTION_ROUTE
          debug 'FIFO: call'
          @session.direction = 'fifo'
          @session.fifo = fifo
          return

        when ACTION_LOGIN
          debug 'FIFO: log in'
          yield @action 'answer'
          yield @fifo_add fifo, @source
          yield @action 'playback', 'ivr/ivr-you_are_now_logged_in.wav'
          yield @action 'hangup'
          return

        when ACTION_LOGOUT
          debug 'FIFO: log out'
          yield @action 'answer'
          yield @fifo_del fifo, @source
          yield @action 'playback', 'ivr/ivr-you_are_now_logged_out.wav'
          yield @action 'hangup'
          return

        else
          yield @action 'hangup'
          return
