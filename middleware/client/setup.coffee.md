    seem = require 'seem'
    pkg = require '../../package.json'
    @name = "#{pkg.name}:middleware:client:setup"
    debug = (require 'debug') @name

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

      @session.context ?= @data['Channel-Context']
      unless m = @session.context?.match /^(\S+)-(ingress|egress|transfer)(?:-(\S+))?$/
        debug 'Ignoring malformed context', @session.context
        return

      @session.profile = m[1]
      @session.direction = m[2]
      @session.reference ?= m[3]

      if @session.direction is 'transfer'
        @session.direction = 'egress'
        @session.transfer = true

The `reference` is used to track a given call through various systems and associate parameters (e.g. client information) to the call as a whole.
In case of a transfer, the session identifier is included in the context.

      @session.reference ?= @req.variable 'session_reference'
      @session.reference ?= @req.header 'X-CCNQ-Reference'
      unless @session.reference?
        @session.reference = uuidV4()
        debug 'Assigned new session.reference', @session.reference

      yield @get_ref()
      @session.reference_data.call_state = 'routing'

      @session.call_reference_data =
        uuid: @call.uuid
        start_time: new Date() .toJSON()
      @session.reference_data.calls ?= []
      @session.reference_data.calls.push @session.call_reference_data

      yield @save_ref()

      @session.sip_profile = @req.variable 'sip_profile'
      @session.sip_profile_client ?= "#{pkg.name}-#{@session.profile}-egress"
      @session.sip_profile_carrier ?= "#{pkg.name}-#{@session.profile}-ingress"
      if @session.direction is 'ingress'
        @session.sip_profile ?= @session.sip_profile_client
      if @session.direction is 'egress'
        @session.sip_profile ?= @session.sip_profile_carrier

      reference_context = [ @session.sip_profile_client, session_reference ].join '-'
      yield @set
        session_reference: @session.reference
        force_transfer_context: ['transfer', @session.reference].join '-'
        'sip_h_X-CCNQ-Reference': @session.reference
      yield @export
        session_reference: @session.reference

      debug 'Ready',
        direction: @session.direction
        profile: @session.profile
        sip_profile: @session.sip_profile
        reference: reference

      return
