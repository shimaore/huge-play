    pkg = require '../../../package'
    @name = "#{pkg.name}:middleware:client:egress:fifo"
    seem = require 'seem'

    @include = seem ->
      return unless @session.direction is 'egress'
      return unless @session.dialplan is 'centrex'
      return if @session.forwarding is true

      unless @session.number_domain
        @debug 'No number domain'
        return

      return unless m = @destination.match /^(81\d|82|83|84)(\d+)$/

      action = m[1]
      number = parseInt m[2], 10

The destination matched.

      ACTION_FIFO_ROUTE = '810'
      ACTION_FIFO_LOGIN = '811'
      ACTION_FIFO_VOICEMAIL = '817'
      ACTION_FIFO_LOGOUT = '819'
      ACTION_CONF_ROUTE = '82'
      ACTION_MENU_ROUTE = '83'
      ACTION_INTERCEPT = '84'

      @debug 'Routing', action, number

      @session.number_domain_data ?= yield @cfg.prov
        .get "number_domain:#{@session.number_domain}"
        .catch (error) =>
          @debug.csr "number_domain #{number_domain}: #{error}"
          {}

      get = (name) =>

        items = @session.number_domain_data[name]

        unless items?
          @debug.csr "Number domain has no #{name}."
          return

        unless items.hasOwnProperty number
          @debug.dev "No property #{number} in #{name} of #{@session.number_domain}"
          return

        item = items[number]
        item.name ?= "#{number}"
        item

      route = (name,type) =>
        item = get name
        return unless item?
        @session[type] = item
        @direction type
        return

      switch action

        when ACTION_CONF_ROUTE
          @debug 'Conf: call'
          route 'conferences', 'conf'
          return

        when ACTION_MENU_ROUTE
          @debug 'Menu: call'
          route 'menus', 'menu'
          return

        when ACTION_FIFO_ROUTE
          @debug 'FIFO: call'
          route 'fifos', 'fifo'
          return

        when ACTION_INTERCEPT
          uuid = yield @redis.getAsync "inbound_call:#{number}@#{@session.number_domain}"
          @debug 'Intercept', uuid
          if uuid?
            yield @set intercept_unbridged_only: true
            yield @action 'intercept', uuid
            @direction 'intercepted'
          else
            yield @action 'hangup'
          return

        when ACTION_FIFO_LOGIN
          @debug 'FIFO: log in'
          fifo = get 'fifos'
          return unless fifo?
          yield @action 'answer'
          yield @fifo_add fifo, @source
          yield @action 'playback', 'ivr/ivr-you_are_now_logged_in.wav'
          yield @action 'hangup'
          return

        when ACTION_FIFO_LOGOUT
          @debug 'FIFO: log out'
          fifo = get 'fifos'
          return unless fifo?
          yield @action 'answer'
          yield @fifo_del fifo, @source
          yield @action 'playback', 'ivr/ivr-you_are_now_logged_out.wav'
          yield @action 'hangup'
          return

        when ACTION_FIFO_VOICEMAIL
          @debug 'FIFO: voicemail'
          fifo = get 'fifos'
          unless fifo.user_database?
            yield @action 'hangup'
            return
          @destination = 'inbox'
          @source = 'user-database'
          @session.voicemail_user_database = fifo.user_database
          @session.voicemail_user_id = fifo.name
          @direction 'voicemail'

        else
          @debug 'Unknown action', action
          yield @action 'hangup'
          return
