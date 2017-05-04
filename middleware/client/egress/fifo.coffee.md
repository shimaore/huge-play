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

      return unless m = @destination.match /^(81\d|82|83|84|88)(\d*)$/

      action = m[1]
      if m[2] is ''
        number = null
      else
        number = parseInt m[2], 10

The destination matched.

      ACTION_FIFO_ROUTE = '810'
      ACTION_QUEUER_LOGIN = '811'
      ACTION_QUEUER_LEAVE = '812'
      ACTION_QUEUER_OFFHOOK = '813'
      ACTION_FIFO_VOICEMAIL = '817'
      ACTION_QUEUER_LOGOUT = '819'
      ACTION_CONF_ROUTE = '82'
      ACTION_MENU_ROUTE = '83'
      ACTION_INTERCEPT = '84'
      ACTION_EAVESDROP = '88'

      @debug 'Routing', action, number

      @session.number_domain_data ?= yield @cfg.prov
        .get "number_domain:#{@session.number_domain}"
        .catch (error) =>
          @debug.csr "number_domain #{number_domain}: #{error}"
          {}

      get = (name,type) =>

        items = @session.number_domain_data[name]

        unless items?
          @debug.csr "Number domain has no #{name}."
          return

        unless number? and items.hasOwnProperty number
          @debug.dev "No property #{number} in #{name} of #{@session.number_domain}"
          return

        item = items[number]
        if item?
          item.short_name ?= "#{type}-#{number}"
          item.name ?= item.short_name
          item.full_name ?= "#{item.short_name}@#{@session.number_domain}"
        item

      route = (name,type) =>
        item = get name, type
        return false unless item?
        @session[type] = item
        @direction type
        true

      agent_tags = =>
        tags = []
        {skills,queues} = @session.number
        if skills?
          for skill in skills
            tags.push "skill:#{skill}"
        if queues?
          for queue in queues
            tags.push "queue:#{queue}"
        tags

This works only for centrex.

      full_source = "#{@source}@#{@session.number_domain}"

      failed = =>
        @debug 'Failed'
        @direction 'failed'
        @action 'hangup' # keep last

      switch action

        when ACTION_CONF_ROUTE
          @debug 'Conf: call'
          unless route 'conferences', 'conf'
            return failed()
          return

        when ACTION_MENU_ROUTE
          @debug 'Menu: call'
          unless route 'menus', 'menu'
            return failed()
          return

        when ACTION_FIFO_ROUTE
          @debug 'FIFO: call'
          unless route 'fifos', 'fifo'
            return failed()
          return

        when ACTION_INTERCEPT
          return failed() unless number?

          uuid = yield @redis.getAsync "inbound_call:#{number}@#{@session.number_domain}"
          @debug 'Intercept', uuid
          return failed() unless uuid?

          yield @set intercept_unbridged_only: true
          yield @action 'intercept', uuid
          @direction 'intercepted' # Really `intercepting`, but oh well
          return

        when ACTION_EAVESDROP
          return failed() unless number?

          inbound_uuid = yield @redis.getAsync "inbound:#{number}@#{@session.number_domain}"
          outbound_uuid = yield @redis.getAsync "outbound:#{number}@#{@session.number_domain}"
          @debug 'Eavesdrop', inbound_uuid, outbound_uuid
          switch
            when inbound_uuid?
              uuid = inbound_uuid
              yield @set
                eavesdrop_bridge_aleg: true
                eavesdrop_bridge_bleg: true
                eavesdrop_whisper_aleg: true
                eavesdrop_whisper_bleg: false
            when outbound_uuid?
              uuid = outbound_uuid
              yield @set
                eavesdrop_bridge_aleg: true
                eavesdrop_bridge_bleg: true
                eavesdrop_whisper_aleg: false
                eavesdrop_whisper_bleg: true
            else
              return failed()

          yield @set
            eavesdrop_indicate_failed: 'tone_stream://%(125,0,300)'
            eavesdrop_indicate_new: 'tone_stream://%(125,0,600);%(125,0,450)'
            eavesdrop_indicate_idle: 'tone_stream://%(125,125,450);%(125,0,450)'
            eavesdrop_enable_dtmf: true
          yield @action 'eavesdrop', uuid
          @direction 'eavesdropping'
          return

        when ACTION_QUEUER_LOGIN
          @debug 'Queuer: log in'
          fifo = get 'fifos', 'fifo'
          yield @action 'answer'
          yield @sleep 2000
          yield @queuer_login full_source, fifo, agent_tags()
          yield @action 'gentones', '%(100,20,300);%(100,20,450);%(100,20,600)'
          yield @action 'hangup'
          @direction 'completed'
          return

        when ACTION_QUEUER_OFFHOOK
          @debug 'Queuer: off-hook agent'
          fifo = get 'fifos', 'fifo'
          yield @action 'answer'
          yield @sleep 2000
          yield @set
            hangup_after_bridge: false
            park_after_bridge: true
          yield @queuer_offhook full_source, @call, fifo, agent_tags()
          @direction 'queuer-offhook'
          return

        when ACTION_QUEUER_LEAVE
          @debug 'Queuer: leave queue'
          fifo = get 'fifos', 'fifo'
          return failed() unless fifo?
          yield @action 'answer'
          yield @sleep 2000
          yield @queuer_leave full_source, fifo
          yield @action 'gentones', '%(100,20,600);%(100,20,450);%(100,20,600)'
          yield @action 'hangup'
          @direction 'completed'
          return

        when ACTION_QUEUER_LOGOUT
          @debug 'Queuer: log out'
          fifo = get 'fifos', 'fifo'
          yield @action 'answer'
          yield @sleep 2000
          yield @queuer_logout full_source, fifo
          yield @action 'gentones', '%(100,20,600);%(100,20,450);%(100,20,300)'
          yield @action 'hangup'
          @direction 'completed'
          return

        when ACTION_FIFO_VOICEMAIL
          @debug 'FIFO: voicemail'
          fifo = get 'fifos', 'fifo'
          return failed() unless fifo?.user_database?
          @destination = 'inbox'
          @source = 'user-database'
          @session.voicemail_user_database = fifo.user_database
          @session.voicemail_user_id = fifo.full_name
          @direction 'voicemail'

        else
          @debug 'Unknown action', action
          return failed()
