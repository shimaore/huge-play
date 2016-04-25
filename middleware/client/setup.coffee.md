    pkg = require '../../package.json'
    @name = "#{pkg.name}:middleware:client:setup"
    debug = (require 'debug') @name

* doc.local_number Record with an identifier `number:<local-number>@<number-domain>`. These records are used on the client-side SBCs. They are one of the two types of `doc.number`.
* doc.number If the identifier of a number contains a `@` character, it is a `doc.local_number`.
* doc.local_number._id (required) `number:<local-number>@<number-domain>`
* doc.local_number.type (required) `number`
* doc.local_number.number (required) `<local-number>@<number-domain>`

    @include = ->

      context = @req.variable 'context' # otherwise @data['Caller-Context']
      unless m = context.match /^(\S+)-(ingress|egress)$/
        debug 'Ignoring malformed context', context
        return

      @session.direction = m[2]
      @session.profile = m[1]
      @session.sip_profile = @req.variable 'sip_profile'
      if @session.direction is 'ingress'
        @session.sip_profile ?= "#{pkg.name}-#{@session.profile}-egress"
      if @session.direction is 'egress'
        @session.sip_profile ?= "#{pkg.name}-#{@session.profile}-ingress"

      debug 'Ready',
        direction: @session.direction
        profile: @session.profile
        sip_profile: @session.sip_profile

      return
