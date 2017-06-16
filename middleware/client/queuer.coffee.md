    @name = 'huge-play:middleware:queuer'
    debug = (require 'tangible') @name
    seem = require 'seem'
    pkg = name:'huge-play'

    queuer = require 'black-metal/queuer'
    request = require 'superagent'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    API = require 'black-metal/api'
    {TaggedCall,TaggedAgent} = require 'black-metal/tagged'

    @notify = ->

      @configure dial_calls: true

      @register 'queuer', 'calls'

      @cfg.statistics.on 'queuer', (data) =>
        @socket.emit 'queuer', data

      queuer = @cfg.queuer
      Agent = @cfg.queuer_Agent

      @register 'queuer:get-agent-state', 'dial_calls'
      @register 'queuer:log-agent-out', 'dial_calls'

      @socket.on 'queuer:get-agent-state', seem (key) =>
        debug 'queue:get-agent-state', key
        agent = new Agent queuer, key
        state = yield agent.get_state().catch -> null
        missed = yield agent.get_missed().catch -> 0
        # async
        agent.notify state, {missed}
        debug 'queue:get-agent-state: done', key, state
        return

      @socket.on 'queuer:log-agent-out', seem (key) =>
        debug 'queue:log-agent-out', key
        agent = new Agent queuer, key
        yield agent.clear_tags()
        yield agent.transition 'logout'
        debug 'queue:log-agent-out: done', key, state
        return

      @register 'queuer:get-egress-pool', 'dial_calls'
      @register 'queuer:egress-pool', 'calls'

      @socket.on 'queuer:get-egress-pool', seem (domain) =>
        debug 'queuer:get-egress-pool', domain

        # FIXME only reply if we are serving the domain

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

      redis = @cfg.redis_client
      prov = @cfg.prov
      profile = @cfg.session?.profile
      api = API @cfg
      host = @cfg.host
      p = @cfg.profiles?[profile]
      if p?
        port = p.egress_sip_port ? p.sip_port+10000

      return unless redis? and prov? and profile? and host? and port?

      class HugePlayCall extends TaggedCall

        redis: redis
        api: api
        profile: "#{pkg.name}-#{profile}-egress"
        get_reference_data: (reference) ->
          cfg.get_session_reference_data reference
        update_reference_data: seem (data,call_reference_data) ->
          data.host ?= cfg.host
          data = yield cfg.update_session_reference_data data, call_reference_data
          cfg.statistics.emit 'reference', data

      class HugePlayAgent extends TaggedAgent

        redis: redis

        new_call: (data) -> new HugePlayCall data

        notify: seem (new_state,data) ->
          debug 'agent.notify', @key, new_state
          notification =
            _in: [
              "endpoint:#{@key}"
              "number:#{@key}"
            ]
            state: new_state

          notification.tags = yield @tags().catch -> []

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

          {account,queuer_webhook} = @number_domain_data

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
          _id = cfg.reference_id()
          data = {
            _id
            _in: [
              "endpoint:#{endpoint}"
              "number:#{endpoint}" # Centrex-only
              "account:#{account}"
              "number_domain:#{@domain}"
            ]
            host: host
            state: 'created'
            endpoint
            account
            destination: body.destination
            domain: "#{host}:#{port}"
            tags: body.tags
            block_dtmf: true
            params:
              sip_invite_params: "xref=#{_id}"
              origination_caller_id_number: @number
          }

          debug 'create_egress_call: saving reference', data
          yield cfg.update_session_reference_data data,
            uuid: 'create-egress-call'
            session: "create-egress-call-#{data._id}"
            start_time: new Date() .toJSON()

          call = new HugePlayCall
            destination: data._id
            tags: body.tags

          yield call.set_remote_number body.destination

          # async
          @notify 'create-egress-call', data

          debug 'create_egress_call: complete'

          return call

      Queuer = queuer
        redis: @cfg.redis_client
        Agent: HugePlayAgent
        Call: HugePlayCall
      @cfg.queuer_Agent = HugePlayAgent
      @cfg.queuer_Call = HugePlayCall
      @cfg.queuer = new Queuer @cfg
      return

    @include = seem ->

      if @session.reference_data?.block_dtmf
        yield @action 'block_dtmf'

      queuer = @cfg.queuer
      Agent = @cfg.queuer_Agent

      return unless queuer? and Agent?

      start_of_call = seem ({key,id}) ->
        debug 'Start of call', key, id
        agent = new Agent queuer, key
        yield agent.add_call id

      end_of_call = seem ({key,id}) ->
        debug 'End of call', key, id
        yield sleep 2*1000
        agent = new Agent queuer, key
        yield agent.del_call id

      @call.once 'inbound', start_of_call
      @call.once 'outbound', start_of_call
      @call.once 'inbound-end', end_of_call
      @call.once 'outbound-end', end_of_call

On-hook agent

      @queuer_login = seem (source,fifo,tags = []) ->
        debug 'queuer_login', source
        agent = new Agent queuer, source
        yield agent.add_tags tags
        yield agent.add_tag "queue:#{fifo.full_name}" if fifo?.full_name?
        yield agent.accept_onhook()
        agent

      @queuer_leave = seem (source,fifo) ->
        debug 'queuer_leave', source
        agent = new Agent queuer, source
        yield agent.del_tag "queue:#{fifo.full_name}" if fifo?.full_name?
        agent

      @queuer_logout = seem (source,fifo) ->
        debug 'queuer_logout', source
        agent = new Agent queuer, source
        yield agent.del_tag "queue:#{fifo.full_name}" if fifo?.full_name?
        yield agent.clear_tags()
        yield agent.transition 'logout'
        agent

Off-hook agent

      @queuer_offhook = seem (source,{uuid},fifo,tags = []) ->
        debug 'queuer_offhook', source, uuid, fifo
        agent = new Agent queuer, source
        agent.clear_tags()
        yield agent.add_tags tags
        yield agent.add_tag "queue:#{fifo.full_name}" if fifo?.full_name?
        yield agent.accept_offhook uuid
        agent
