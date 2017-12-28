    seem = require 'seem'
    pkg = require '../../package.json'
    @name = "#{pkg.name}:middleware:client:setup"
    debug = (require 'tangible') @name

* doc.local_number Record with an identifier `number:<local-number>@<number-domain>`. These records are used on the client-side SBCs. They are one of the two types of `doc.number`.
* doc.number If the identifier of a number contains a `@` character, it is a `doc.local_number`.
* doc.local_number._id (required) `number:<local-number>@<number-domain>`
* doc.local_number.type (required) `number`
* doc.local_number.number (required) `<local-number>@<number-domain>`

Config
======

Note that client-side the fields are called `profiles` and are stored in the JSON configuration.

Call-Processing
===============

    @include = seem ->

Session Context
---------------

For example, in `@data` we might get:

```
'Channel-Context': 'sbc-ingress',
variable_sofia_profile_name: 'huge-play-sbc-ingress',
variable_recovery_profile_name: 'huge-play-sbc-ingress',
```

The `sofia_profile_name` above is the one for the inbound leg (`A` leg). For the outbound leg we use the profile "on the other side"; its name is stored in  @session.sip_profile .

* session.context (string) The original Sofia Context for this (ingress) call.

For calls originating internally, module `exultant-songs` will use the `origination_context` variable.
We load it first because otherwise the `Channel-Context` value (`default`) set by originate will take precedence.

      @session.context ?= @req.variable 'origination_context'

The channel-context is set (for calls originating from sofia-sip) by the `context` parameter of the Sofia instance that carries the A leg.

      @session.context ?= @data['Channel-Context']

      @debug '>>>> New call', @session.context, @data

      unless m = @session.context?.match /^(\S+)-(ingress|egress|transfer|handled)(?:-(\S+))?$/
        @debug.dev 'Malformed context', @session.context
        return @respond '500 Malformed context'

      @session.profile = m[1]
      @direction m[2]
      @session.reference ?= m[3]

Session Reference
-----------------

* session.reference (string) Identifies a call spanning multiple FreeSwitch servers.

The `reference` is used to track a given call through various systems and associate parameters (e.g. client information) to the call as a whole.
In case of a transfer, the session identifier might be included in the context.
In case of a call from `exultant-songs`, the session identifier is in variable `session_reference`.

      @session.reference ?= @req.variable 'session_reference'

In all other cases, look (very hard) for a `xref` parameter.

      reference_in = (name) =>
        v = @req.variable name
        return unless v?
        m = v.match /xref[=:]([\w-]+)/
        if m? and m[1]?
          @session.reference ?= m[1]
        else
          @debug "#{name} #{v} has no xref"

      reference_in 'sip_from_params'
      reference_in 'sip_to_params'
      reference_in 'sip_req_params'
      reference_in 'sip_contact_params'
      reference_in 'sip_referred_by_params'
      reference_in 'sip_h_X-FS-Refer-Params'

If the call was originated by a phone it's normal for it to not have a reference,
in which case one is created.

      {Reference} = @cfg
      @reference = new Reference @session.reference
      @session.reference = @reference.id

Logger
------

      if yield @reference.get_dev_logger()
        @session.dev_logger = true

      @notify state: 'incoming-call-client-side'

SIP Profile
-----------

Define the (sofia-sip) SIP profiles used to send calls out.

      sip_profile_client = "#{pkg.name}-#{@session.profile}-egress"
      sip_profile_carrier = "#{pkg.name}-#{@session.profile}-ingress"
      @session.sip_profile_client ?= sip_profile_client
      @session.sip_profile_carrier ?= sip_profile_carrier

      if @session.direction is 'ingress'
        @session.sip_profile ?= sip_profile_client
      else
        @session.sip_profile ?= sip_profile_carrier

      @session.transfer = false

The default transfer context assumes the transfer request is coming from a customer (egress call) and the customer is transfering the call.

      @session.default_transfer_context = [
        @session.profile
        'transfer'
        @session.reference
      ].join '-'

      if @session.direction is 'transfer' or @req.variable('transfer_source')?
        @session.transfer = true

For a blind transfer (or an attended transfer to FIFO) we'll get:
```
variable_transfer_source: "(unix epoch time):(new profile's uuid):bl_xfer:(destination)/sbc-transfer-(xref)/inline:'socket:… async full'"
variable_sip_h_Referred-By: '["name"] <sip:(referrer)@…;xref:(xref)>',
variable_sip_refer_to: '<sip:(new-dest)@…>',
```

```
Channel-Transfer-Source
Caller-Transfer-Source
variable_transfer_source
variable_transfer_history
variable_pre_transfer_caller_id_name
variable_pre_transfer_caller_id_number
```

        sip_refer_to = @req.variable 'sip_refer_to'
        sip_referred_by = @req.variable 'sip_h_Referred-By'

        if sip_refer_to? and sip_referred_by?
          @debug 'source', @source
          m = sip_refer_to.match /sip:(\d+)@/
          @debug 'refer_to', m[1]
          @session.refer_to = m[1]
          @destination = m[1]
          m = sip_referred_by.match /sip:(\d+@[^;]+)/
          @debug 'referred_by', m[1]
          referred_by = m[1]
          @session.referred_by = m[1]
          @session.wait_for_aleg_ack = false      # in huge-play
          @session.sip_wait_for_aleg_ack = false  # in tough-rate

        @direction 'egress'

The handled transfer context assumes the transfer request is coming from a (presumably trusted) server. It is used by the tough-rate call-handler.
For now this should only happen when a customer calls a global number that points to a conference, and the server that handled the request isn't the one serving the conference.

      @session.handled_transfer_context = [
        @session.profile
        'handled'
        @session.reference
      ].join '-'

      if @session.direction is 'handled'
        @session.transfer = true
        @direction 'handled'

SIP Profile Data
----------------

Note that client-side the fields are called `profiles` and are stored in the JSON configuration.

* session.local_server (string, host:port) URI domain-part usable for REFER, etc. so that other servers might redirect calls to us (client-side only).

      p = @cfg.profiles?[@session.profile]
      if p?
        @session.local_server = "#{@cfg.host}:#{p.ingress_sip_port ? p.sip_port}"
        @session.client_server = "#{@cfg.host}:#{p.egress_sip_port ? p.sip_port+10000}"
      else
        @debug.dev 'Missing profile', @session.profile

Set FreeSwitch variables
------------------------

      sip_params = "xref=#{@session.reference}"
      our_dialplan = "inline:'socket:127.0.0.1:#{@cfg.port ? 5702} async full'"

      yield @set
        session_reference: @session.reference
        force_transfer_context: @session.default_transfer_context
        # force_transfer_dialplan: our_dialplan

      yield @export
        session_reference: @session.reference

Info for handling of 302 etc. for (I assume) our outbound calls. `cfg.port` is from `thinkable-ducks/server`.

        sip_redirect_profile: @session.profile
        sip_redirect_context: @session.default_transfer_context
        sip_redirect_dialplan: our_dialplan
        sip_redirect_contact_params: sip_params

        sip_invite_params: sip_params
        sip_invite_to_params: sip_params
        sip_invite_contact_params: sip_params
        sip_invite_from_params: sip_params

      @debug 'Ready',
        reference: @session.reference
        call: @call.uuid
        session: @session._id
        context: @session.context
        direction: @session.direction
        destination: @destination
        source: @source
        transfer: @session.transfer
        profile: @session.profile
        sip_profile: @session.sip_profile
        default_transfer_context: @session.default_transfer_context
        wait_for_aleg_ack: @session.wait_for_aleg_ack ? null
        local_server: @session.local_server ? null

      return
