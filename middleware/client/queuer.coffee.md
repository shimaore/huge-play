    @name = 'huge-play:middleware:client:queuer'
    {debug,foot} = (require 'tangible') @name
    pkg = name:'huge-play'
    Moment = require 'moment-timezone'
    {SUBSCRIBE,UPDATE} = require 'red-rings/operations'

    queuer = require 'black-metal/queuer'
    request = require 'superagent'

    run = require 'flat-ornament'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    domain_of = (key) ->
      key?.split('@')[1]

    now = (tz = 'UTC') ->
      Moment().tz(tz).format()

    {TaggedCall,TaggedAgent} = require 'black-metal/tagged'
    monitor = require 'screeching-eggs/monitor'
    FS = require 'esl'
    RedisInterface = require 'normal-key/interface'

    @server_pre = ->

      cfg = @cfg

      HugePlayReference = @cfg.Reference
      {api,prov,host} = @cfg
      profile = @cfg.session?.profile
      p = @cfg.profiles?[profile]
      if p?
        port = p.egress_sip_port ? p.sip_port+10000

      unless cfg.local_redis_client? and prov? and profile? and host? and port? and api? and HugePlayReference?
        @debug.dev 'Missing configuration'
        return

How long should we keep the state of a call after the last update?

      call_timeout = 8*3600

How long should we keep the state of an agent after the last update?

      agent_timeout = 12*3600

HugePlayCall
------------

      class HugePlayCall extends TaggedCall

        interface: new RedisInterface cfg.local_redis_client, call_timeout
        __api: api

        profile: "#{pkg.name}-#{profile}-egress"
        Reference: HugePlayReference

        build_notification: (data) ->
          notification =
            report_type: 'queuer'
            host: host
            now: Date.now()

            domain: await @get_domain().catch -> null
            key: @key
            id: await @get_id().catch -> null
            destination: await @get_destination().catch -> null

            call_state: await @state().catch -> null
            remote_number: await @get_remote_number().catch -> null
            alert_info: await @get_alert_info().catch -> null
            reference: await @get_reference().catch -> null
            session: await @get_session().catch -> null
            answered: await @answered().catch -> null
            presenting: await @count().catch -> null
            tags: await @tags().catch -> []

          for own k,v of data when v?
            switch k
              when 'agent', 'call', 'agent_call', 'remote_call'
                v = v.key if typeof v isnt 'string'
            notification[k] ?= v

          notification

        notify: (data) ->
          debug 'call.notify', data
          notification = await @build_notification data

          if notification.domain?
            cfg.rr.notify "domain:#{notification.domain}", "call:#{notification.id}", notification

          debug 'call.notify: send', notification
          notification

HugePlayAgent
-------------

      class HugePlayAgent extends TaggedAgent

        interface: new RedisInterface cfg.local_redis_client, agent_timeout

        notify: (data) ->
          debug 'agent.notify', @key, data

          {old_state,state,event,reason} = data

          notification =
            report_type: 'queuer'
            host: host
            now: Date.now()

            state: state
            old_state: old_state
            event: event
            reason: reason
            agent: @key
            number: @number
            number_domain: @domain
            missed: await @get_missed().catch -> 0
            count: await @count().catch -> 0

          notification.tags = await @tags().catch -> []
          agent_name = await (@get 'name').catch -> null
          if agent_name?
            notification.agent_name = agent_name

          offhook = await @get_offhook_call().catch -> null
          if offhook
            notification.offhook = true
          else
            notification.offhook = false

Module `black-metal` 8.3.0 will report the call object as `data.call` (and this is currently the only parameter that might be provided).

If `data.call` is present we notify using the call's process; if it isn't we notify directly.
This avoids sending two messages for the same event (one with incomplete data, the other with complete data).

          if data.call?
            notification = await data.call.notify notification

          cfg.rr.notify "agent:#{notification.agent}", "agent:#{notification.agent}", notification
          debug 'agent.notify: done', @key, notification
          return

        create_egress_call: (body) ->
          debug 'create_egress_call', @domain, body

          @number_domain_data ?= await prov
            .get "number_domain:#{@domain}"
            .catch (error) -> null

          unless @number_domain_data?
            debug 'create_egress_call: missing number-domain', @domain
            return

          {account,queuer_webhook,timezone} = @number_domain_data

          timezone ?= null

          await @set 'timezone', timezone

          unless account?
            debug 'create_egress_call: no account', @domain
            return null

          if not body?
            unless queuer_webhook?
              debug 'create_egress_call: no queuer_webhook', @domain
              return null

            tags = await @tags()
            options = {@key,@number,@domain,tags}
            debug 'create_egress_call: send request', options
            {body} = await request
              .post queuer_webhook
              .send options

          body.tags ?= []
          unless body.destination? and body.tags? and body.tags.length?
            debug 'create_egress_call: incomplete response', @domain, body
            return null

          body.tags.push 'queuer'

          debug 'create_egress_call: creating call', @domain, body
          body.tags.push 'egress'

See `in_domain` in black-metal/tagged.

          body.tags.push "number_domain:#{@domain}"

          endpoint = @key
          reference = new HugePlayReference()
          _id = reference.id

FIXME This is highly inefficient, we should be able to create the structure at once.

          await reference.set_endpoint endpoint
          await reference.set_account account
          await reference.set_number_domain @domain
          await reference.set_number endpoint # Centrex-only
          await reference.set_destination body.destination
          await reference.set_source @number
          await reference.set_domain "#{host}:#{port}"
          # await reference.set_tags body.tags # set_tags = clear_tags() + add_tags()
          await reference.set_block_dtmf true

This is a "fake" call-data entry, to record the data we used to trigger the call for call-reporting purposes.

          call_data =
            uuid: 'create-egress-call'
            session: "#{_id}-create-egress-call"
            reference: _id
            start_time: now timezone
            source: @number
            destination: body.destination
            timezone: timezone

            timestamp: now timezone
            host: host
            type: 'call'

            event: 'create-egress-call'

          call = new HugePlayCall make_id()
          await call.set_domain @domain
          await call.set_started_at()
          await call.set_destination _id # destination endpoint

This probably not necessary, since the destination number is actually retrieved from the reference-data.

          await call.set_remote_number body.destination
          await call.set_tags body.tags
          await call.set 'timezone', timezone

          # async
          @notify call_data

          debug 'create_egress_call: complete'

          return call

Queuer
------

The queuer's Redis is used for call pools and the agents pool.
Since we're bound to a server for domains it's OK to use the local Redis.

      pools_redis_interface = new RedisInterface cfg.local_redis_client, agent_timeout

      class HugePlayQueuer extends queuer pools_redis_interface, Agent: HugePlayAgent, Call: HugePlayCall
        notify: (key,id,data) ->
          notification =
            report_type: 'queuer'
            host: host
            now: Date.now()

          for own k,v of data when typeof v in ['number','string','boolean']
            notification[k] = v

          if data.call?
            notification = await data.call.notify notification
          cfg.rr.notify key, id, notification
          return

      @cfg.queuer = new HugePlayQueuer @cfg

      options =
        host: @cfg.socket_host ? '127.0.0.1'
        port: @cfg.socket_port ? 5722
      client = FS.createClient options
      monitor client, @cfg.queuer.Call

RedRings
--------

RedRings for agents:

      cfg.rr
      .receive 'agent:*'
      .forEach (msg) ->
        switch
          when msg.op is SUBSCRIBE
            # get agent state
            return unless $ = msg.key?.match /^agent:(\S+)$/
            key = $[1]
            is_remote = await cfg.is_remote domain_of key
            return if is_remote isnt false

            debug 'queuer:get-agent-state', key

            agent = new HugePlayAgent key
            state = await agent.state().catch -> null
            await agent.notify {state}

          when msg.op is UPDATE
            # log agent in or out; use redring.create() for login, redring.delete() for logout

            return unless $ = msg.id?.match /^agent:(\S+)$/
            key = $[1]
            is_remote = await cfg.is_remote domain_of key
            return if is_remote isnt false

            if msg.deleted

              debug 'queue:log-agent-out', key

              agent = new HugePlayAgent key
              await agent.clear_tags()
              await agent.transition 'logout'

            else

              tags = []
              {skills,queues,broadcast,timezone} = await cfg.prov.get "number:#{key}"
              if skills?
                for skill in skills
                  tags.push "skill:#{skill}"
              if queues?
                for queue in queues
                  tags.push "queue:#{queue}"
              if broadcast
                tags.push 'broadcast'

              agent = new HugePlayAgent key
              await agent.add_tags tags
              if ornaments?
                ctx = {agent,timezone}
                await run.call ctx, ornaments, @ornaments_commands

              await agent.accept_onhook()

        return

Note: RedRings agent notifications are handled above (in the HugePlayCall and HugePlayAgent classes).

RedRings for pools:

      cfg.rr
      .receive 'pool:*'
      .filter ({op}) -> op is SUBSCRIBE
      .forEach (msg) ->

        return unless $ = msg.key?.match /^pool:(\S+):(ingress|egress)$/

        domain = $[1]
        name = $[2]

        is_remote = await cfg.is_remote domain
        return if is_remote isnt false

        pool = switch name
          when 'ingress'
            queuer.ingress_pool domain

          when 'egress'
            queuer.egress_pool domain

        calls = await pool.calls()
        result = await Promise.all calls.map (call) -> call.build_notification {}

        notification =
          host: host
          now: Date.now()
          calls: result

        cfg.rr.notify msg.key, "number_domain:#{domain}", value

        return

      return

Middleware
==========

    @include = ->

      if await @reference.get_block_dtmf()
        await @action 'block_dtmf'

      queuer = @cfg.queuer
      return unless queuer?

      {Agent,Call} = @cfg.queuer
      return unless Agent? and Call?

Queuer Call object
------------------

      {uuid} = @call

      @queuer_call = (id) ->
        domain = @session.number_domain
        id ?= uuid
        @debug 'queuer_call', id, domain
        queuer_call = new Call id
        await queuer_call.set_domain domain
        await queuer_call.set_started_at()
        await queuer_call.set_id id

        await queuer_call.set_session @session._id
        await queuer_call.set_reference @session.reference
        queuer_call

Agent state monitoring
----------------------

      local_server = [@session.local_server,@session.client_server].join '/'

On-hook agent
-------------

      @queuer_login = (source,name,fifo,tags = [],ornaments) ->
        @debug 'queuer_login', source
        agent = new Agent source
        await agent.set 'name', name
        await agent.add_tags tags
        await agent.add_tag "queue:#{fifo.full_name}" if fifo?.full_name?

* doc.local_number.login_commands: (optional) array of ornaments, applied when a call-center agent logs into the system.

        if ornaments?
          @agent = agent
          await run.call this, ornaments, @ornaments_commands

        await agent.accept_onhook()
        await @report {state:'queuer-login',source,fifo,tags}
        agent

      @queuer_leave = (source,fifo) ->
        @debug 'queuer_leave', source
        agent = new Agent source
        await agent.del_tag "queue:#{fifo.full_name}" if fifo?.full_name?
        await @report {state:'queuer-leave',source,fifo}
        agent

      @queuer_logout = (source,fifo) ->
        @debug 'queuer_logout', source
        agent = new Agent source
        await agent.del_tag "queue:#{fifo.full_name}" if fifo?.full_name?
        await agent.clear_tags()
        await agent.transition 'logout'
        await @report {state:'queuer-logout',source,fifo}
        agent

Off-hook agent
--------------

      @queuer_offhook = (source,name,{uuid},fifo,tags = []) ->
        @debug 'queuer_offhook', source, uuid, fifo
        agent = new Agent source
        await agent.set 'name', name
        agent.clear_tags()
        await agent.add_tags tags
        await agent.add_tag "queue:#{fifo.full_name}" if fifo?.full_name?
        call = await agent.accept_offhook uuid
        return unless call?
        await call.set_session @session._id
        await @report {state:'queuer-offhook',source,fifo,tags}
        agent
