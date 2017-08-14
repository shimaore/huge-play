    @name = 'huge-play:middleware:client:queuer'
    debug = (require 'tangible') @name
    seem = require 'seem'
    pkg = name:'huge-play'
    Moment = require 'moment-timezone'

    queuer = require 'black-metal/queuer'
    request = require 'superagent'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    domain_of = (key) ->
      key?.split('@')[1]

    now = (tz = 'UTC') ->
      Moment().tz(tz).format()

    API = require 'black-metal/api'
    {TaggedCall,TaggedAgent} = require 'black-metal/tagged'
    RedisInterface = require 'normal-key/interface'

    @notify = ->

      queuer = @cfg.queuer
      Agent = @cfg.queuer_Agent

      unless queuer?
        debug.dev 'queuer is not available'
        return

      unless Agent?
        debug.dev 'Agent is not available'
        return

      @configure dial_calls: true

Events received downstream.

      @register 'queuer:get-agent-state', 'dial_calls'
      @register 'queuer:log-agent-out', 'dial_calls'

      @socket.on 'queuer:get-agent-state', seem (key) =>
        debug 'queuer:get-agent-state', key

        is_remote = yield @cfg.is_remote domain_of key
        return if is_remote isnt false

        agent = new Agent queuer, key
        state = yield agent.get_state().catch -> null
        missed = yield agent.get_missed().catch -> 0
        count = yield agent.count().catch -> 0
        # async
        agent.notify state, {missed,count}
        debug 'queuer:get-agent-state: done', key, state
        return

      @socket.on 'queuer:log-agent-out', seem (key) =>
        debug 'queue:log-agent-out', key

        is_remote = yield @cfg.is_remote domain_of key
        return if is_remote isnt false

        agent = new Agent queuer, key
        yield agent.clear_tags()
        yield agent.transition 'logout'
        debug 'queue:log-agent-out: done', key
        return

Downstream/upstream pair for egress-pool retrieval.

      @register 'queuer:get-egress-pool', 'dial_calls'
      @register 'queuer:egress-pool', 'calls'

      @socket.on 'queuer:get-egress-pool', seem (domain) =>
        debug 'queuer:get-egress-pool', domain

        is_remote = yield @cfg.is_remote domain
        return if is_remote isnt false

        tag = "number_domain:#{domain}"
        calls = yield queuer.egress_pool.not_presenting()
        result = []
        for call in calls
          if yield call.has_tag(tag).catch( -> null )
            result.push
              key: call.key
              destination: call.destination
              tags: yield call.tags().catch -> []

        notification =
          _in: [ tag ]
          calls: result
        @socket.emit 'queuer:egress-pool', notification
        debug 'queuer:get-egress-pool: done', domain, notification
        return

    @server_pre = ->

      cfg = @cfg

      local_redis = @cfg.local_redis_client
      prov = @cfg.prov
      profile = @cfg.session?.profile
      api = API @cfg
      host = @cfg.host
      p = @cfg.profiles?[profile]
      if p?
        port = p.egress_sip_port ? p.sip_port+10000

      unless local_redis? and prov? and profile? and host? and port?
        @debug.dev 'Missing configuration'
        return

      HugePlayReference = @cfg.Reference
      local_redis_interface = new RedisInterface [local_redis]

      class HugePlayCall extends TaggedCall

        redis: local_redis_interface
        api: api
        profile: "#{pkg.name}-#{profile}-egress"
        Reference: HugePlayReference

        report: seem (data) ->
          debug 'call.report', data
          notification =
            _queuer: true
            host: host
            now: Date.now()

            key: @key
            id: @id
            destination: @destination

            remote_number: yield @get_remote_number().catch -> null
            alert_info: yield @alert_info().catch -> null
            reference: yield @reference().catch -> null
            session: yield @get_session().catch -> null
            bridged: yield @bridged().catch -> null
            presenting: yield @count().catch -> null
            tags: yield @tags().catch -> []

          for own k,v of data
            notification[k] ?= v

          cfg.statistics.emit 'queuer', notification
          debug 'call.report: send', notification
          return

      class HugePlayAgent extends TaggedAgent

        redis: local_redis_interface

        new_call: (data) -> new HugePlayCall data

        notify: seem (new_state,data,event = null) ->
          debug 'agent.notify', @key, new_state
          notification =
            _queuer: true
            _in: [
              "endpoint:#{@key}"
              "number:#{@key}"
              "number_domain:#{@domain}"
            ]
            _notify: true
            host: host
            now: Date.now()

            state: new_state
            event: event
            agent: @key
            number: @number
            number_domain: @domain

The dialplan is used e.g. to know which messages to forward to the socket.io bus.

            dialplan: 'centrex'

          notification.tags = yield @tags().catch -> []
          agent_name = yield (@get 'name').catch -> null
          if agent_name?
            notification.agent_name = agent_name

          offhook = yield @get_offhook_call().catch -> null
          if offhook
            notification.offhook = true
          else
            notification.offhook = false

          for own k, v of data
            notification[k] ?= v

          cfg.statistics.emit 'queuer', notification
          debug 'agent.notify: done', @key, notification
          return

        create_egress_call: seem ->
          debug 'create_egress_call', @domain

          @number_domain_data ?= yield prov
            .get "number_domain:#{@domain}"
            .catch (error) -> null

          unless @number_domain_data?
            debug 'create_egress_call: missing number-domain', @domain
            return

          {account,queuer_webhook,timezone} = @number_domain_data

          timezone ?= null

          yield @set 'timezone', timezone

          unless account?
            debug 'create_egress_call: no account', @domain
            return null

          unless queuer_webhook?
            debug 'create_egress_call: no queuer_webhook', @domain
            return null

          tags = yield @tags()
          options = {@key,@number,@domain,tags}
          debug 'create_egress_call: send request', options
          {body} = yield request
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

          yield reference.add_in [
            "endpoint:#{endpoint}"
            "number:#{endpoint}" # Centrex-only
            "account:#{account}"
            "number_domain:#{@domain}"
          ]
          yield reference.set_endpoint endpoint
          yield reference.set_account account
          yield reference.set_destination body.destination
          yield reference.set_source @number
          yield reference.set_domain "#{host}:#{port}"
          yield reference.set_tags body.tags
          yield reference.set_block_dtmf true

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

          call = @new_call
            destination: _id

          yield call.save()

This probably not necessary, since the destination number is actually retrieved from the reference-data.

          yield call.set_remote_number body.destination
          yield call.set_tags body.tags
          yield call.set 'timezone', timezone

          # async
          @notify 'create-egress-call', call_data

          debug 'create_egress_call: complete'

          return call

The queuer's Redis is used for call pools and the agents pool.
Since we're bound to a server for domains it's OK to use the local Redis.

      Queuer = queuer
        redis: local_redis_interface
        Agent: HugePlayAgent
        Call: HugePlayCall
      @cfg.queuer_Agent = HugePlayAgent
      @cfg.queuer_Call = HugePlayCall
      @cfg.queuer = new Queuer @cfg
      return

    @include = seem ->

      if yield @reference.get_block_dtmf()
        yield @action 'block_dtmf'

      queuer = @cfg.queuer
      Agent = @cfg.queuer_Agent

      return unless queuer? and Agent?

      local_server = [@session.local_server,@session.client_server].join '/'

      start_of_call = seem ({key,id,dialplan}) =>
        debug 'Start of call', key, id, dialplan

        return unless dialplan is 'centrex'
        is_remote = yield @cfg.is_remote (domain_of key), local_server
        return if is_remote isnt false

        @report event:'start-of-call', agent:key

        agent = new Agent queuer, key
        yield agent.add_call id

      end_of_call = seem ({key,id,dialplan}) =>
        debug 'End of call', key, id, dialplan

        return unless dialplan is 'centrex'
        is_remote = yield @cfg.is_remote (domain_of key), local_server
        return if is_remote isnt false

        @report event:'end-of-call', agent:key

        yield sleep 2*1000
        agent = new Agent queuer, key
        yield agent.del_call id

      @call.once 'inbound', start_of_call
      @call.once 'outbound', start_of_call
      @call.once 'inbound-end', end_of_call
      @call.once 'outbound-end', end_of_call

On-hook agent

      @queuer_login = seem (source,name,fifo,tags = []) ->
        debug 'queuer_login', source
        agent = new Agent queuer, source
        yield agent.set 'name', name
        yield agent.add_tags tags
        yield agent.add_tag "queue:#{fifo.full_name}" if fifo?.full_name?
        yield agent.accept_onhook()
        yield @report {state:'queuer-login',source,fifo,tags}
        agent

      @queuer_leave = seem (source,fifo) ->
        debug 'queuer_leave', source
        agent = new Agent queuer, source
        yield agent.del_tag "queue:#{fifo.full_name}" if fifo?.full_name?
        yield @report {state:'queuer-leave',source,fifo}
        agent

      @queuer_logout = seem (source,fifo) ->
        debug 'queuer_logout', source
        agent = new Agent queuer, source
        yield agent.del_tag "queue:#{fifo.full_name}" if fifo?.full_name?
        yield agent.clear_tags()
        yield agent.transition 'logout'
        yield @report {state:'queuer-logout',source,fifo}
        agent

Off-hook agent

      @queuer_offhook = seem (source,name,{uuid},fifo,tags = []) ->
        debug 'queuer_offhook', source, uuid, fifo
        agent = new Agent queuer, source
        yield agent.set 'name', name
        agent.clear_tags()
        yield agent.add_tags tags
        yield agent.add_tag "queue:#{fifo.full_name}" if fifo?.full_name?
        call = yield agent.accept_offhook uuid
        return unless call?
        yield call.set_session @session._id
        yield @report {state:'queuer-offhook',source,fifo,tags}
        agent
