    seem = require 'seem'
    pkg = require '../../package.json'
    @name = "#{pkg.name}:middleware:client:setup"

    uuidV4 = require 'uuid/v4'

* doc.local_number Record with an identifier `number:<local-number>@<number-domain>`. These records are used on the client-side SBCs. They are one of the two types of `doc.number`.
* doc.number If the identifier of a number contains a `@` character, it is a `doc.local_number`.
* doc.local_number._id (required) `number:<local-number>@<number-domain>`
* doc.local_number.type (required) `number`
* doc.local_number.number (required) `<local-number>@<number-domain>`

    @include = seem ->

For example, in `@data` we might get:

```
'Channel-Context': 'sbc-ingress',
variable_sofia_profile_name: 'huge-play-sbc-ingress',
variable_recovery_profile_name: 'huge-play-sbc-ingress',
```

The `sofia_profile_name` above is the one for the inbound leg (`A` leg). For the outbound leg we use the profile "on the other side"; its name is stored in  @session.sip_profile .

The channel-context is set (for calls originating from sofia-sip) by the `context` parameter of the Sofia instance that carries the A leg.
For calls originating internally, module `exultant-songs` will use the `origination_context` variable.
We load it first because otherwise the `Channel-Context` value (`default`) set by originate will take precedence.

      @session.context ?= @req.variable 'origination_context'
      @session.context ?= @data['Channel-Context']

      unless m = @session.context?.match /^(\S+)-(ingress|egress|transfer|handled)(?:-(\S+))?$/
        @debug.dev 'Ignoring malformed context', @session.context
        return

      @session.profile = m[1]
      @session.direction = m[2]
      @session.reference ?= m[3]

The `reference` is used to track a given call through various systems and associate parameters (e.g. client information) to the call as a whole.
In case of a transfer, the session identifier is included in the context.
In case of a call from `exultant-songs`, the session identifier is in variable `session_reference`.

      @session.reference ?= @req.variable 'session_reference'
      @session.reference ?= @req.header 'X-CCNQ-Reference'
      unless @session.reference?
        @session.reference = uuidV4()
        @debug 'Assigned new session.reference', @session.reference

      yield @get_ref()
      @session.reference_data.call_state = 'routing'

      @session.call_reference_data =
        uuid: @call.uuid
        session: @session._id
        start_time: new Date() .toJSON()
      @session.reference_data.calls ?= []
      @session.reference_data.calls.push @session.call_reference_data

      yield @save_ref()

Force the destination for `exultant-songs` calls (`originate` sets `Channel-Destination-Number` to the value of `Channel-Caller-ID-Number`).

      if @session.reference_data.destination?
        @destination = @session.reference_data.destination
        @session.reference_data.destination = null

Also, do not wait for an ACK, since we're calling out (to the "caller") when using exultant-songs.

        @session.wait_for_aleg_ack = false      # in huge-play
        @session.sip_wait_for_aleg_ack = false  # in tough-rate

        yield @action 'ring_ready'

      @session.sip_profile_client ?= "#{pkg.name}-#{@session.profile}-egress"
      @session.sip_profile_carrier ?= "#{pkg.name}-#{@session.profile}-ingress"

      if @session.direction is 'ingress'
        @session.sip_profile ?= @session.sip_profile_client
      else
        @session.sip_profile ?= @session.sip_profile_carrier

The default transfer context assumes the call is coming from a customer (egress call) and the customer is transfering the call.

      @session.default_transfer_context = [
        @session.profile
        'transfer'
        @session.reference
      ].join '-'

      if @session.direction is 'transfer'
        @session.direction = 'egress'
        @session.transfer = true

The handled transfer context assumes the call is coming from a (presumably trusted) server; for now this should only happen when a customer calls a global number that points to a conference, and the server that handled the request isn't the one serving the conference.

      @session.handled_transfer_context = [
        @session.profile
        'handled'
        @session.reference
      ].join '-'

      if @session.direction is 'handled'
        @session.direction = 'handled'
        @session.transfer = true

* session.local_server (string, host:port) URI domain-part usable for REFER, etc. so that other servers might redirect calls to us

      p = @cfg.profiles?[@session.profile]
      if p?
        @session.local_server = "#{@cfg.host}:#{p.ingress_sip_port ? p.sip_port}"
      else
        @debug.dev 'Missing profile', @session.sip_profile

      yield @set
        session_reference: @session.reference
        force_transfer_context: @session.default_transfer_context
        'sip_h_X-CCNQ-Reference': @session.reference
      yield @export
        session_reference: @session.reference
        'sip_h_X-CCNQ-Reference': @session.reference

      @debug 'Ready',
        direction: @session.direction
        destination: @destination
        profile: @session.profile
        sip_profile: @session.sip_profile
        reference: @session.reference

      return
