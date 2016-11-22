    pkg = require '../../package.json'
    @name = "#{pkg.name}:middleware:client:setup"
    debug = (require 'debug') @name

* doc.local_number Record with an identifier `number:<local-number>@<number-domain>`. These records are used on the client-side SBCs. They are one of the two types of `doc.number`.
* doc.number If the identifier of a number contains a `@` character, it is a `doc.local_number`.
* doc.local_number._id (required) `number:<local-number>@<number-domain>`
* doc.local_number.type (required) `number`
* doc.local_number.number (required) `<local-number>@<number-domain>`

    @include = ->

For example, in `@data` we might get:

```
'Channel-Context': 'sbc-ingress',
variable_sofia_profile_name: 'huge-play-sbc-ingress',
variable_recovery_profile_name: 'huge-play-sbc-ingress',
```

The `sofia_profile_name` above is the one for the inbound leg (`A` leg). For the outbound leg we use the profile "on the other side"; its name is stored in @session.sip_profile .

      context = @data['Channel-Context']
      unless m = context.match /^(\S+)-(ingress|egress)$/
        debug 'Ignoring malformed context', context
        return

      @session.direction = m[2]
      @session.profile = m[1]
      @session.sip_profile = @req.variable 'sip_profile'
      @session.sip_profile_client ?= "#{pkg.name}-#{@session.profile}-egress"
      @session.sip_profile_carrier ?= "#{pkg.name}-#{@session.profile}-ingress"
      if @session.direction is 'ingress'
        @session.sip_profile ?= @session.sip_profile_client
      if @session.direction is 'egress'
        @session.sip_profile ?= @session.sip_profile_carrier

      debug 'Ready',
        direction: @session.direction
        profile: @session.profile
        sip_profile: @session.sip_profile

      return
