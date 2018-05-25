    pkg = require '../../../package'
    @name = "#{pkg.name}:middleware:client:egress:fifo"

    @include = ->
      return unless @session?.direction is 'egress'
      return unless @session.dialplan is 'centrex'
      return if @session.forwarding is true

      unless @session.number_domain
        @debug 'No number domain'
        return

      return unless m = @destination.match /^(80\d\d|81\d|82|83|84|87|88)(\d*)$/

      action = m[1]
      if m[2] is ''
        number = null
      else
        number = parseInt m[2], 10
        key = "#{number}@#{@session.number_domain}"

* doc.local_number:groups (array of string) Contains groups the user belong too. The convention is to use `:` as a separator. For example: ['sales:internal','support:modems']

        {groups} = number_data = await @cfg
          .prov.get "number:#{key}"
          .catch -> {}

      events = @cfg.queuer?.Agent?.events

      spy = (monitor) =>

        unless events
          @debug.dev 'No `events`, cannot spy'

Which is a-leg or b-leg still needs to be confirmed, I have some suspicion this is wrong for some scenarios.

        ours_is_aleg = =>
          await @set
            eavesdrop_bridge_aleg: true
            eavesdrop_bridge_bleg: true
            eavesdrop_whisper_aleg: monitor
            eavesdrop_whisper_bleg: false

        ours_is_bleg = =>
          await @set
            eavesdrop_bridge_aleg: true
            eavesdrop_bridge_bleg: true
            eavesdrop_whisper_aleg: false
            eavesdrop_whisper_bleg: monitor

        eavesdrop = (uuid,notify) =>
          await @cfg.api "uuid_broadcast #{uuid} gentones::%(125,0,450)" if notify and monitor
          await @action 'eavesdrop', uuid

        events.on [key,'onhook','bridge'], (call) =>
          uuid = await call.get_id()
          await ours_is_aleg()
          await eavesdrop uuid, true

        events.on [key,'offhook','bridge'], (call) =>
          uuid = await call.get_id()
          await ours_is_aleg()
          await eavesdrop uuid, true

        events.on [key,'remote','bridge'], (call,disposition,our_call) =>
          uuid = await our_call.get_id()
          await ours_is_aleg()
          await eavesdrop uuid, true

        events.on [key,'external','bridge'], (call,disposition,our_call) =>
          uuid = await our_call.get_id()
          await ours_is_aleg()
          await eavesdrop uuid, true

        await @action 'answer'
        await @sleep 200

        return

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
      ACTION_MONITOR = '87'
      ACTION_EAVESDROP = '88'

      ACTION_MSG_RECORD = '8011'
      ACTION_MSG_ACTIVATE = '8012'
      ACTION_MSG_DEACTIVATE = '8013'
      ACTION_MSG_LISTEN = '8014'

      @debug 'Routing', action, number

      @session.number_domain_data ?= await @cfg.prov
        .get "number_domain:#{@session.number_domain}"
        .catch (error) =>
          @debug.csr "number_domain #{number_domain}: #{error}"
          {}

* doc.local_number:allowed_groups (array of string) Contains group prefixes that the given user may eavesdrop/monitor. The convention is to use `:` as a path separator. For example: ['sales','support:modems']. See doc.local_number.groups for the groups assigned to a target.

      is_allowed = (allowed_groups,target_groups) ->
        target_groups?.some (name) ->
          allowed_groups?.some (prefix) ->
            name.substr(0,prefix.length) is prefix

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
          if type is 'conf'
            item.full_name ?= "#{@session.number_domain}-#{item.short_name}"
          else
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
        {skills,queues,broadcast} = @session.number
        if skills?
          for skill in skills
            tags.push "skill:#{skill}"
        if queues?
          for queue in queues
            tags.push "queue:#{queue}"
        if broadcast
          tags.push 'broadcast'
        tags

This works only for centrex.

      agent = @session.agent ? "#{@source}@#{@session.number_domain}"
      agent_name = @session.agent_name ? @source
      {allowed_groups} = agent_data = await @cfg
        .prov.get "number:#{agent}"
        .catch -> {}

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

          uuid = await @local_redis.get "inbound_call:#{number}@#{@session.number_domain}"
          @debug 'Intercept', uuid
          return failed() unless uuid?

          await @set intercept_unbridged_only: true
          await @action 'intercept', uuid
          @direction 'intercepted' # Really `intercepting`, but oh well
          return

Eavesdrop: call to listen (no notification, no whisper).

        when ACTION_EAVESDROP
          @debug 'Eavesdrop', number, allowed_groups, groups
          return failed() unless number?
          return failed() unless is_allowed allowed_groups, groups

          @debug 'Eavesdrop'
          await @set
            eavesdrop_indicate_failed: 'silence_stream://125'
            eavesdrop_indicate_new: 'silence_stream://125'
            eavesdrop_indicate_idle: 'silence_stream://125'
            eavesdrop_enable_dtmf: true

          spy false
          @direction 'eavesdropping'
          return

Monitor: call to listen (with notification beep), and whisper

        when ACTION_MONITOR
          @debug 'Monitor', number, allowed_groups, groups
          return failed() unless number?
          return failed() unless is_allowed allowed_groups, groups

          @debug 'Monitor'
          await @set
            eavesdrop_indicate_failed: 'tone_stream://%(125,0,300)'
            eavesdrop_indicate_new: 'tone_stream://%(125,0,600);%(125,0,450)'
            eavesdrop_indicate_idle: 'tone_stream://%(125,125,450);%(125,0,450)'
            eavesdrop_enable_dtmf: true

          spy true
          @direction 'eavesdropping'
          return

        when ACTION_QUEUER_LOGIN
          @debug 'Queuer: log in'
          fifo = get 'fifos', 'fifo'
          await @action 'answer'
          await @sleep 2000
          @session.timezone ?= @session.number.timezone
          await @queuer_login agent, agent_name, fifo, agent_tags(), @session.number.login_ornaments
          await @action 'gentones', '%(100,20,300);%(100,20,450);%(100,20,600)'
          await @action 'hangup'
          @direction 'completed'
          return

        when ACTION_QUEUER_OFFHOOK
          @debug 'Queuer: off-hook agent'
          fifo = get 'fifos', 'fifo'
          await @action 'answer'
          await @sleep 2000
          await @set
            hangup_after_bridge: false
            park_after_bridge: true
          await @queuer_offhook agent, agent_name, @call, fifo, agent_tags()
          @direction 'queuer-offhook'
          return

        when ACTION_QUEUER_LEAVE
          @debug 'Queuer: leave queue'
          fifo = get 'fifos', 'fifo'
          return failed() unless fifo?
          await @action 'answer'
          await @sleep 2000
          await @queuer_leave agent, fifo
          await @action 'gentones', '%(100,20,600);%(100,20,450);%(100,20,600)'
          await @action 'hangup'
          @direction 'completed'
          return

        when ACTION_QUEUER_LOGOUT
          @debug 'Queuer: log out'
          fifo = get 'fifos', 'fifo'
          await @action 'answer'
          await @sleep 2000
          await @queuer_logout agent, fifo
          await @action 'gentones', '%(100,20,600);%(100,20,450);%(100,20,300)'
          await @action 'hangup'
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

Menu messages

        when ACTION_MSG_DEACTIVATE
          @debug 'deactivate message'

          await @action 'answer'
          await @sleep 2000

          doc = @session.number_domain_data
          doc.msg ?= {}
          doc.msg[number] ?= {}
          doc.msg[number].active = false
          await @cfg.master_push doc

          await @action 'gentones', '%(200,20,600);%(200,20,450)'
          @direction 'completed'

        when ACTION_MSG_ACTIVATE
          @debug 'activate message'

          await @action 'answer'
          await @sleep 2000

          doc = @session.number_domain_data
          doc.msg ?= {}
          doc.msg[number] ?= {}
          doc.msg[number].active = true
          await @cfg.master_push doc

          await @action 'gentones', '%(200,20,450);%(200,20,600)'
          @direction 'completed'

        when ACTION_MSG_RECORD
          @debug 'record message'

          await @action 'answer'
          await @sleep 2000

          doc = @session.number_domain_data
          file = "msg-#{number}.mp3"
          uri = @prompt.uri 'master-prov', 'ignore', doc._id, file, doc._rev
          await @prompt.record uri

          await @action 'hangup'
          @direction 'completed'

        when ACTION_MSG_LISTEN
          @debug 'listen to message'

          await @action 'answer'
          await @sleep 2000

          doc = @session.number_domain_data
          file = "msg-#{number}.mp3"
          uri = @prompt.uri 'prov', 'ignore', doc._id, file
          await @action 'playback', uri

          await @action 'hangup'
          @direction 'completed'

        else
          @debug 'Unknown action', action
          return failed()
