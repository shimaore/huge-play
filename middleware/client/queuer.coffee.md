    @name = 'huge-play:middleware:queuer'
    debug = (require 'debug') @name
    seem = require 'seem'
    pkg = name:'huge-play'

    queuer = require 'black-metal/queuer'
    request = require 'superagent'

    API = require 'black-metal/api'
    {TaggedCall,TaggedAgent} = require 'black-metal/tagged'

    @notify = ->

      @socket.emit 'register',
        event: 'queuer',
        default_room: 'calls'

      @cfg.statistics.on 'queuer', (data) =>
        @socket.emit 'queuer', data

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

      class HugePlayAgent extends TaggedAgent

        redis: redis

        new_call: (data) -> new HugePlayCall data

        notify: (new_state,data) ->
          notification =
            _in: [
              "endpoint:#{@key}"
              "number:#{@key}"
            ]
            state: new_state
            data: data

          cfg.statistics.emit 'queuer', notification

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

          debug 'create_egress_call: send request', @domain
          {body} = yield request
            .post queuer_webhook
            .send {@key,@number,@domain,tags:@tags()}

          body.tags ?= []
          unless body.destination? and body.tags? and body.tags.length?
            debug 'create_egress_call: incomplete response', @domain, body
            return null

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
            params:
              sip_invite_params: "'xref=#{_id}'"
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

    @include = ->

      queuer = @cfg.queuer
      Agent = @cfg.queuer_Agent

      return unless queuer? and Agent?

      start_of_call = seem ({key,id}) ->
        debug 'Start of call', key, id
        agent = new Agent queuer, key
        yield agent.add_call id

      end_of_call = seem ({key,id}) ->
        debug 'End of call', key, id
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