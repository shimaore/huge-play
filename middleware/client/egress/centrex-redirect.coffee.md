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

      key = "#{@source}@#{@session.number_domain}"
      eavesdrop_key = "outbound:#{key}"
      {queuer} = @cfg

      unless @session.transfer or @call.closed

Typical supervised transfer on outbound call:
```
-- Initial call (from extension to external number)
CHANNEL_PRESENT 34@test 0_179807936@192.168.4.66
-- Bridge extensio to external number (via LCR)
CHANNEL_BRIDGE 34@test 0_179807936@192.168.4.66 37563dc4-fac2-4f20-b5b4-2b4f23bd6fa8
-- Second call (to voicemail)
CHANNEL_PRESENT 34@test 0_684242152@192.168.4.66
-- Transfer (by extension)
-- Un-bridge call from extension to LCR
CHANNEL_UNBRIDGE 34@test 0_179807936@192.168.4.66 37563dc4-fac2-4f20-b5b4-2b4f23bd6fa8 recv_replace ANSWER
-- The supervised transfer is realized as a new call
CHANNEL_PRESENT 37563dc4-fac2-4f20-b5b4-2b4f23bd6fa8
-- Hangup call to voicemail (it was never bridged)
CHANNEL_HANGUP_COMPLETE 34@test 0_684242152@192.168.4.66 replaced ANSWER
-- Hangup call to LCR
CHANNEL_HANGUP_COMPLETE 34@test 0_179807936@192.168.4.66 recv_replace ANSWER
```

        @debug 'Set outbound eavesdrop', eavesdrop_key
        yield @local_redis?.setex eavesdrop_key, eavesdrop_timeout, @call.uuid

        debug 'CHANNEL_PRESENT', key, @call.uuid
        yield queuer?.track key, @call.uuid
        yield queuer?.on_present @call.uuid
        @report event:'start-of-call', agent:key

        yield @call.event_json 'CHANNEL_BRIDGE', 'CHANNEL_UNBRIDGE', 'CHANNEL_HANGUP_COMPLETE'

Bridge on calling side of call.

        @call.on 'CHANNEL_BRIDGE', hand ({body}) =>
          a_uuid = body['Bridge-A-Unique-ID']
          b_uuid = body['Bridge-B-Unique-ID']
          return unless @call.uuid is a_uuid
          debug 'CHANNEL_BRIDGE', key, a_uuid, b_uuid

          yield queuer?.track key, a_uuid
          yield queuer?.on_bridge a_uuid
          return

Unbridge on calling side of call.

        @call.on 'CHANNEL_UNBRIDGE', hand ({body}) =>
          a_uuid = body['Bridge-A-Unique-ID']
          b_uuid = body['Bridge-B-Unique-ID']
          return unless @call.uuid is a_uuid
          disposition = body?.variable_transfer_disposition
          debug 'CHANNEL_UNBRIDGE', key, a_uuid, b_uuid, disposition, body.variable_endpoint_disposition

          if disposition is 'replaced'
            yield queuer?.track key, b_uuid
            yield @local_redis?.setex eavesdrop_key, eavesdrop_timeout, b_uuid
          else
            yield @local_redis?.del eavesdrop_key

          yield queuer?.on_unbridge a_uuid
          yield queuer?.untrack key, a_uuid

          @report event:'end-of-call', agent:key
          return

This is to handle the case of calls that never get bridged (since in this case we never get to `CHANNEL_UNBRIDGE, and the above call to `on_present` is never cancelled).

        @call.once 'CHANNEL_HANGUP_COMPLETE', hand ({body}) =>
          a_uuid = body[Unique_ID]
          return unless @call.uuid is a_uuid
          disposition = body?.variable_transfer_disposition
          debug 'CHANNEL_HANGUP_COMPLETE', key, @call.uuid, disposition, body.variable_endpoint_disposition

No need to do it on `recv_replace` since it was preceded by UNBRIDGE.

          unless disposition is 'recv_replace'
            yield @local_redis?.del eavesdrop_key
            yield queuer?.on_unbridge @call.uuid
            yield queuer?.untrack key, @call.uuid
            @report event:'end-of-call', agent:key
          return

      @debug 'Ready'
