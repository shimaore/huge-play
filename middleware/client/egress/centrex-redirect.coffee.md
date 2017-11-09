    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:centrex-redirect"
    {debug,hand,heal} = (require 'tangible') @name

    Unique_ID = 'Unique-ID'

    default_eavesdrop_timeout = 8*3600 # 8h

    @include = seem ->

      return unless @session.direction is 'egress'
      return unless @session.dialplan is 'centrex'

Transfer Workaround
-------------------

      is_remote = yield @cfg.is_remote @session.number_domain, [@session.local_server,@session.client_server].join '/'

      if is_remote
        server = is_remote.split('/')[1]
        @report {state:'centrex-redirect', server}

        uri = "<sip:#{@destination}@#{server};xref=#{@session.reference}>"
        @debug 'Handling is remote', uri

Send a REFER to a call which is already answered. (Typically, coming from `exultant-songs`.)

        if @data['Answer-State'] is 'answered'
          uri = "<sip:#{@destination}@#{@session.number_domain};xref=#{@session.reference}?Via=#{server}>"
          res = yield @action 'deflect', uri

For an unanswered call (the default/normal behavior for a call coming from a phone),
send a 302 back to OpenSIPS; OpenSIPS interprets the 302 and submits to the remote server.

        else
          res = yield @action 'redirect', uri

        @debug 'Redirection returned', uri, res

Make sure there is no further processing.

        @direction 'transferred'
        return

Centrex Handling
----------------

      @debug 'Handling is local'

Eavesdrop registration
----------------------

      {eavesdrop_timeout} = @cfg
      eavesdrop_timeout ?= default_eavesdrop_timeout

      key = @session.agent
      eavesdrop_key = "outbound:#{key}"
      {queuer} = @cfg

      unless @call.closed

        @debug 'Set outbound eavesdrop', eavesdrop_key
        yield @local_redis?.setex eavesdrop_key, eavesdrop_timeout, @call.uuid

        debug 'CHANNEL_PRESENT', key, @call.uuid

        if queuer?
          agent = new queuer.Agent queuer, key

Bind the agent to the call.

          yield @queuer_call?.set_agent key

Add the call to the agent.

          yield agent.add_call @call.uuid

Monitor the a-leg.

          yield queuer.monitor_local_call @queuer_call if @queuer_call?

Note: inside the queuer, since these calls are never pooled, so their state does not evolve.

        @report event:'start-of-call', agent:key, call:@call.uuid

      @debug 'Ready'
