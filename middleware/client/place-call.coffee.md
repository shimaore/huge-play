Auto-call
---------

This module places calls (presumably towards a client or Centrex extension) and sends them into the socket we control.
It ensures data is retrieved and injected in the call.

This module also triggers calls from within a conference.

    seem = require 'seem'
    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:place-call"
    debug = (require 'tangible') @name

    escape = (v) ->
      "#{v}".replace ',', ','

    make_params = (data) ->
      ("#{k}=#{escape v}" for own k,v of data).join ','

    @handler = handler = (cfg,ev) ->

      save_ref = seem (data,call) ->
        data = yield cfg.update_session_reference_data data, call
        ev.emit 'reference', data
        data

* cfg.session.profile (string) Configuration profile that should be used to place calls towards client, for automated calls.

      profile = cfg.session?.profile
      unless profile?
        debug 'Missing cfg.session.profile, not starting.'
        return

      sofia_profile = "huge-play-#{profile}-egress"
      context = "#{profile}-egress"

      unless cfg.update_session_reference_data?
        debug 'Missing cfg.update_session_reference_data, not starting.'
        return

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
        debug 'Received place-call', data

A proper call UUID is required.

        return unless _id?.match /^\d{4}-\d{2}[\w-]+$/

Load additional data from the endpoint.

        endpoint_data = yield cfg.prov.get("endpoint:#{endpoint}").catch -> null
        return unless endpoint_data?
        return if endpoint_data.disabled or endpoint_data.src_disabled

        {account} = endpoint_data

Ensure only one FreeSwitch server processes those.

        domain = endpoint_data.number_domain ? 'default.local'

Note that Centrex-redirect uses both the local-server and the client-server.

        is_remote = yield cfg.is_remote(domain, [local_server,client_server].join '/').catch -> true
        return if is_remote

FIXME The data sender must do resolution of the endpoint_via and associated translations????
ANSWER: Yes. And store the result in `caller`.

        debug 'place-call: Placing call'

Call Reference Data

        call =
          uuid: "place-call-#{_id}"
          session: _id
          start_time: new Date() .toJSON()

Session Reference Data

        data._in = [
          "endpoint:#{endpoint}"
          "account:#{account}"
        ]
        data.tags ?= []
        data.host = host
        data.account = account
        data.state = 'connecting-caller'

        data.callee_name ?= pkg.name
        data.callee_num ?= data.destination

        data = yield save_ref data, call

        xref = "xref=#{_id}"
        params = make_params

Ensure we can track the call by forcing its UUID.

          origination_uuid: call.uuid

These are used by `huge-play/middleware/client/setup`.

          session_reference: _id
          origination_context: context
          sip_invite_params: xref
          sip_invite_to_params: xref
          sip_invite_contact_params: xref
          sip_invite_from_params: xref

And `ccnq4-opensips` requires `X-CCNQ3-Endpoint` for routing.

          'sip_h_X-CCNQ3-Endpoint': data.endpoint

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

        debug "Calling #{cmd}"

        res = yield cfg.api(cmd).catch (error) ->
          msg = error.stack ? error.toString()
          debug "originate: #{msg}"
          msg

The `originate` command will return when the call is answered by the callee (or an error occurred).

        debug "Originate returned", res
        if res[0] is '+'
          data.tags.push 'caller-connected'
        else
          data.tags.push 'caller-failed'

        data = yield save_ref data, call

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

A proper call UUID is required.

        return unless data._id?.match /^\d{4}-\d{2}[\w-]+$/

Ensure we are co-located with the FreeSwitch instance serving this conference.

        is_remote = yield cfg.is_remote(name, local_server).catch -> true
        return if is_remote

Load additional data from the endpoint.

        endpoint_data = yield cfg.prov.get("endpoint:#{endpoint}").catch -> null
        return unless endpoint_data?
        return if endpoint_data.disabled or endpoint_data.src_disabled

        {account} = endpoint_data

Try to get the asserted number, assuming Centrex.

        number_data = yield cfg.prov.get("number:#{endpoint}").catch -> {}
        calling_number = number_data.asserted_number ? endpoint.split('@')[0]

        {language} = data
        language ?= number_data.language
        language ?= endpoint_data.language

Duplicated from exultant-song (FIXME)

        debug 'call-to-conference: Placing call'

Call Reference Data

        call =
          uuid: "call-to-conference-#{_id}"
          session: _id
          start_time: new Date() .toJSON()

Session Reference Data

        data._in = [
          "endpoint:#{endpoint}"
          "account:#{account}"
        ]
        data.tags ?= []
        data.host = host
        data.account = account
        data.state = 'connecting'
        data.call_options =
          group_confirm_key: '5' # if `exec`, `file` holds the application and parameters; otherwise, one or more chars to confirm
          group_confirm_file: 'phrase:conference:confirm:5' # defaults to `silence`
          group_confirm_error_file: 'phrase:conference:confirm:5'
          group_confirm_read_timeout: 15000 # defaults to 5000
          group_confirm_cancel_timeout: false
          language: language

        data = yield save_ref data, call

Call it out

        xref = "xref:#{_id}"
        params = make_params

Ensure we can track the call by forcing its UUID.

          origination_uuid: call.uuid

          sip_invite_params: xref
          sip_invite_to_params: xref
          sip_invite_contact_params: xref
          sip_invite_from_params: xref

          origination_caller_id_number: calling_number

And `huge-play` requires these for routing an egress call.

          'sip_h_P-Charge-Info': "sip:#{account}@#{host}"
          'sip_h_X-CCNQ3-Endpoint': endpoint

        sofia = "{#{params}}sofia/#{sofia_profile}/sip:#{destination}@#{host}:#{port}"
        cmd = "originate #{sofia} &conference(#{name}++flags{})"

        debug "Calling #{cmd}"
        res = yield cfg.api(cmd).catch (error) ->
          msg = error.stack ? error.toString()
          debug "conference: #{msg}"
          msg

        debug "Conference returned", res

        data = yield save_ref data, call

    @notify = ({cfg,socket}) ->

      handler cfg, socket

      @register 'place-call', 'dial_calls'
      @register 'call-to-conference', 'dial_calls'
      @configure dial_calls: true

      debug 'Module Ready'

    @include = ->
