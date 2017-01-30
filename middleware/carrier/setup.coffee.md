    seem = require 'seem'
    pkg = require '../../package.json'
    @name = "#{pkg.name}:middleware:carrier:setup"
    debug = (require 'debug') @name

    uuidV4 = require 'uuid/v4'

* doc.global_number Record with an identifier `number:<global-number>`. These records are used between the carrier SBCs and the client SBCs. They are one of the two types of `doc.number`.
* doc.number If the identifier of a number does not contain a `@` character, it is a `doc.global_number`.
* doc.global_number._id (required) `number:<global-number>`
* doc.global_number.number (required) `<global-number>`, where the global-number has the standard format `<country-code><national-number>`. The format is identical to the E.164 format but the `+` sign at the start is omitted.

Config
======

    @config = seem ->

Create the proper profiles and ACLs

      @cfg.profiles = {}
      @cfg.acls = {}

      @cfg.host_data =
        if @cfg.host?
          debug "Retrieving data for #{@cfg.host}"
          yield @cfg.prov
            .get "host:#{@cfg.host}"
            .catch (error) =>
              @debug.ops "Host #{@cfg.host}: #{error}"
              {}
        else
          @debug.dev 'No cfg.host'
          {}

      @cfg.sip_profiles ?= @cfg.host_data.sip_profiles ? {}

      debug 'Configuring SIP Profiles', @cfg.sip_profiles

      for own name,profile of @cfg.sip_profiles
        p =
          local_ip: profile.ingress_sip_ip
          socket_port: @cfg.port ? 5702
        p[k] = v for own k,v of profile
        @cfg.profiles[name] = p

        @cfg.acls["#{name}-ingress"] = profile.ingress_acl ? []
        @cfg.acls["#{name}-egress"] = profile.egress_acl ? []

      null

Server
======

Load the host record so that we can retrieve the `sip_profiles` at runtime.

    @server_pre = seem ->
      @cfg.host_data =
        if @cfg.host?
          debug "Retrieving data for #{@cfg.host}"
          yield @cfg.prov
            .get "host:#{@cfg.host}"
            .catch (error) =>
              # @debug.ops "Host #{@cfg.host}: #{error}"
              debug "Host #{@cfg.host}: #{error}"
              {}
        else
          # @debug.dev 'No cfg.host'
          debug 'No cfg.host'
          {}

      @cfg.sip_profiles ?= @cfg.host_data.sip_profiles ? {}

      debug 'Configuring SIP Profiles', @cfg.sip_profiles
      null

    @include = seem ->

First start with the same code as client-side.

      context = @data['Channel-Context']
      unless m = context.match /^(\S+)-(ingress|egress|handled)(?:-(\S+))?$/
        @debug.dev 'Ignoring malformed context', context
        return

      @session.profile = m[1]
      @session.direction = m[2]
      @session.reference ?= m[3]

      if @session.direction is 'handled'
        @session.direction = 'handled'
        @session.transfer = true

The `reference` is used to track a given call through various systems and associate parameters (e.g. client information) to the call as a whole.
In case of a transfer, the session identifier is included in the context.
Otherwise, since the call is coming from a carrier we force the creation of a new context.

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

Define the (sofia-sip) SIP profiles used to send calls out.

      @session.sip_profile = @req.variable 'sip_profile'
      if @session.direction is 'ingress'
        @session.sip_profile ?= "#{pkg.name}-#{@session.profile}-egress"
      else
        @session.sip_profile ?= "#{pkg.name}-#{@session.profile}-ingress"

The handled transfer context assumes the transfer request is coming from a (presumably trusted) server. It is used by the tough-rate call-handler.

      @session.handled_transfer_context = [
        @session.profile
        'handled'
        @session.reference
      ].join '-'

Note that carrier-side the fields are called `sip_profiles` and are stored in the database.
The FreeSwitch configuration uses the `profiles` field, which defaults to using port 5080.

      @session.profile_data = @cfg.sip_profiles[@session.profile]

      yield @set
        session_reference: @session.reference
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
