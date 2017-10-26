Auto-call
---------

This module places calls (presumably towards a client or Centrex extension) and sends them into the socket we control.
It ensures data is retrieved and injected in the call.

This module also triggers calls from within a conference.

    seem = require 'seem'
    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:place-call"
    {debug,hand} = (require 'tangible') @name
    Moment = require 'moment-timezone'

    escape = (v) ->
      "#{v}".replace ',', ','

    make_params = (data) ->
      ("#{k}=#{escape v}" for own k,v of data).join ','

    now = (tz = 'UTC') ->
      Moment().tz(tz).format()

    @handler = handler = (cfg,ev) ->

      if cfg.local_redis_client?
        elected = seem (key) ->
          name = "elected-#{key}"
          winner = yield cfg.local_redis_client
            .setnx name, false
            .catch -> null
          if winner
            yield cfg.local_redis_client
              .expire name, 60
              .catch -> yes
          else
            debug 'Lost the election.'
          return winner
      else
        elected = -> Promise.resolve true

* cfg.session.profile (string) Configuration profile that should be used to place calls towards client, for automated calls.

      profile = cfg.session?.profile
      unless profile?
        debug.dev 'Missing cfg.session.profile, not starting.'
        return

      sofia_profile = "huge-play-#{profile}-egress"
      context = "#{profile}-egress"

See huge-play/conf/freeswitch

      host = cfg.host
      p = cfg.profiles?[profile]
      if host and p?
        port = p.egress_sip_port ? p.sip_port+10000
        socket_port = p.socket_port ? 5721
      else
        debug 'Missing cfg.host or cfg.profiles[profile], not starting.', {profile}
        return

Note: if there are multiple profiles in use we will get in trouble at that point. (FIXME)

      local_server = "#{cfg.host}:#{p.ingress_sip_port ? p.sip_port}"
      client_server = "#{cfg.host}:#{p.egress_sip_port ? p.sip_port+10000}"
      debug 'Using', {local_server,client_server}

      {Reference} = cfg

Place Call
----------

The calls are automatically sent back to ourselves so that they can be processed like regular outbound calls.

This feature will call an extension (client-side number) and when the extension picks the call up, it will call the destination number (either an internal or external destination).

Event parameters:
- `_id` (YYYY-MM-UUID)
- `endpoint`
- 'caller' (with appropriate `endpoint_via` translations if necessary)
- `destination`
- `callee_name` (optional)
- `callee_num` (optional)
- `call_timeout` (optional)

      ev.on 'place-call', seem (data) =>
        {endpoint,caller,_id} = data

        data.callee_name ?= pkg.name
        data.callee_num ?= data.destination

FIXME The data sender must do resolution of the endpoint_via and associated translations????
ANSWER: Yes. And store the result in the field `caller`.

        debug 'Received place-call', data

A proper reference is required.

        return unless _id? and _id.match /^[\w-]+$/

Load additional data from the endpoint.

        endpoint_data = yield cfg.prov.get("endpoint:#{endpoint}").catch -> null
        return unless endpoint_data?
        return if endpoint_data.disabled or endpoint_data.src_disabled

        {account,timezone} = endpoint_data

Ensure only one FreeSwitch server processes those.

        domain = endpoint_data.number_domain
        return unless domain?

Note that Centrex-redirect uses both the local-server and the client-server.

        is_remote = yield cfg.is_remote(domain, [local_server,client_server].join '/').catch -> true
        return if is_remote

        debug 'place-call: Placing call'

Session Reference Data

        my_reference = new Reference _id

        yield my_reference.add_in [
          "endpoint:#{endpoint}"
          "account:#{account}"
          "number_domain:#{domain}"
        ]
        yield my_reference.set_account account
        yield my_reference.set_destination data.destination

        xref = "xref=#{_id}"
        params = make_params

These are used by `huge-play/middleware/client/setup`.

          session_reference: _id
          origination_context: context
          sip_invite_params: xref
          sip_invite_to_params: xref
          sip_invite_contact_params: xref
          sip_invite_from_params: xref

And `ccnq4-opensips` requires `X-En` for routing.

          'sip_h_X-En': data.endpoint

        sofia = "{#{params}}sofia/#{sofia_profile}/sip:#{caller}"

        command = "socket(127.0.0.1:#{socket_port} async full)"

        argv = [
          sofia
          "'&#{command}'"

dialplan

          'none'

context

          context

cid_name -- callee_name, shows on the caller's phone and in Channel-(Orig-)Callee-ID-Name

          data.callee_name

cid_num -- called_num, shows on the caller's phone and in Channel-(Orig-)Callee-ID-Number

          data.callee_num

timeout_sec

          data.call_timeout ? ''

        ].join ' '
        cmd = "originate #{argv}"

        return unless yield elected _id

        debug "Calling #{cmd}"

        res = yield cfg.api(cmd).catch (error) ->
          msg = error.stack ? error.toString()
          debug "originate: #{msg}"
          msg

The `originate` command will return when the call is answered by the callee (or an error occurred).

        debug "Originate returned", res
        if res[0] is '+'
          debug 'caller-connected', _id
        else
          debug.dev 'caller-failed', _id

        debug 'Session state:', data.tags

Call to conference
------------------

Parameters:
- `_id` (YYYY-MM-UUID)
- `endpoint`
- `name`
- `destination`

      ev.on 'call-to-conference', seem (data) =>
        {endpoint,name,destination,_id} = data
        debug 'Received call-to-conference', data, local_server

A proper reference is required.

        return unless _id? and _id.match /^[\w-]+$/

Ensure we are co-located with the FreeSwitch instance serving this conference.

        is_remote = yield cfg.is_remote(name, local_server).catch -> true
        return if is_remote

Load additional data from the endpoint.

        endpoint_data = yield cfg.prov.get("endpoint:#{endpoint}").catch -> null
        return unless endpoint_data?
        return if endpoint_data.disabled or endpoint_data.src_disabled

        {account,timezone} = endpoint_data

Try to get the asserted number, assuming Centrex.

        number_data = yield cfg.prov.get("number:#{endpoint}").catch -> {}
        calling_number = number_data.asserted_number ? endpoint.split('@')[0]

        {language} = data
        language ?= number_data.language
        language ?= endpoint_data.language

        timezone ?= data.timezone if data.timezone?

Duplicated from exultant-song (FIXME)

        debug 'call-to-conference: Placing call'

Session Reference Data

        my_reference = new Reference _id

        yield my_reference.add_in [
          "endpoint:#{endpoint}"
          "account:#{account}"
          "number_domain:#{endpoint.number_domain}"
        ]
        yield my_reference.set_account account
        yield my_reference.set_endpoint endpoint
        yield my_reference.set_call_options
          group_confirm_key: '5' # if `exec`, `file` holds the application and parameters; otherwise, one or more chars to confirm
          group_confirm_file: 'phrase:conference:confirm:5' # defaults to `silence`
          group_confirm_error_file: 'phrase:conference:confirm:5'
          group_confirm_read_timeout: 15000 # defaults to 5000
          group_confirm_cancel_timeout: false
          language: language

Call it out

        xref = "xref:#{_id}"
        params = make_params

          sip_invite_params: xref
          sip_invite_to_params: xref
          sip_invite_contact_params: xref
          sip_invite_from_params: xref

          origination_caller_id_number: calling_number

        sofia = "{#{params}}sofia/#{sofia_profile}/sip:#{destination}@#{host}:#{port}"
        cmd = "originate #{sofia} &conference(#{name}++flags{})"

        return unless yield elected _id

        debug "Calling #{cmd}"
        res = yield cfg.api(cmd).catch (error) ->
          msg = error.stack ? error.toString()
          debug "conference: #{msg}"
          msg

        debug "Conference returned", res

Queuer place call
-----------------

The `body` should contains:
- `_id` (unique id for the request)
- `agent` (string)
- `destination` (string)
- `tags` (array)

      ev.on 'create-queuer-call', hand (body) =>
        {queuer} = cfg
        {Agent} = queuer

        unless queuer? and Agent?
          debug 'create-queuer-call: no queuer'
          return

        unless body? and body.agent? and body.destination?
          debug 'create-queuer-call: invalid content', body
          return

        agent = new Agent queuer, body.agent

        is_remote = yield cfg.is_remote(agent.domain, [local_server,client_server].join '/').catch -> true
        if is_remote
          debug 'create-queuer-call: not handled on this server', body
          return

        return unless yield elected body._id

        yield queuer.create_egress_call_for agent, body
        return

      return

Notify
======

    @notify = ({cfg,socket}) ->

      handler cfg, socket

      @register 'place-call', 'dial_calls'
      @register 'call-to-conference', 'dial_calls'
      @register 'create-queuer-call', 'dial_calls'
      @configure dial_calls: true

      debug 'Module Ready'

Click-to-dial (`place-call`)
----------------------------

    @include = seem ->

Force the destination for `place-call` calls (`originate` sets `Channel-Destination-Number` to the value of `Channel-Caller-ID-Number`).

      destination = yield @reference.get_destination()
      if destination?

        @destination = destination
        yield @reference.set_destination null

Also, do not wait for an ACK, since we're calling out (to the "caller"),
and therefor the call is already connected by the time we get here.

        @session.wait_for_aleg_ack = false      # in huge-play
        @session.sip_wait_for_aleg_ack = false  # in tough-rate

Finally, generate a P-Charge-Info header so that the SBCs will allow the call through.

        account = @reference.get_account()
        if account?
          yield @export 'sip_h_P-Charge-Info': "sip:#{account}@#{@cfg.host}"

        @set
          ringback: @session.ringback ? '%(3000,3000,437,1317)'
          instant_ringback: true

"Tonalité d'acheminement", for nostalgia's sake.

        @action 'playback', 'tone_stream://%(50,50,437,1317);loops=-1'

Options might be provided for either `place-call` or `call-to-conference`.
They are used in `tough-rate/middleware/call-handler`.

      options = yield @reference.get_call_options()
      if options?
        @session.call_options = options

      @debug 'Ready', {destination,account,options}
