    seem = require 'seem'
    pkg = require '../../package.json'
    @name = "#{pkg.name}:middleware:carrier:setup"
    debug = (require 'tangible') @name

* doc.global_number Record with an identifier `number:<global-number>`. These records are used between the carrier SBCs and the client SBCs. They are one of the two types of `doc.number`.
* doc.number If the identifier of a number does not contain a `@` character, it is a `doc.global_number`.
* doc.global_number._id (required) `number:<global-number>`
* doc.global_number.number (required) `<global-number>`, where the global-number has the standard format `<country-code><national-number>`. The format is identical to the E.164 format but the `+` sign at the start is omitted.

Config
======

Note that carrier-side the fields are called `sip_profiles` and are stored in the database.
The FreeSwitch configuration uses the `profiles` field, which defaults to using port 5080.

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

Call-Processing
===============

    @include = seem ->

Session Context
---------------

* session.context (string) The original Sofia Context for this (ingress) call.

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

      @session.reference ?= @req.variable 'session_reference'

In all other cases, look (very hard) for a `xref` parameter.

      reference_in = (name) =>
        if m = @req.variable(name)?.match /xref[=:]([\w-]+)/
          @session.reference ?= m[1]

      reference_in 'sip_from_params'
      reference_in 'sip_to_params'
      reference_in 'sip_req_params'
      reference_in 'sip_contact_params'
      reference_in 'sip_referred_by_params'
      reference_in 'sip_h_X-FS-Refer-Params'

Otherwise, since the call is coming from a carrier we force the creation of a new context.

      {Reference} = @cfg
      @reference = new Reference @session.reference
      @session.reference = @reference.id

Logger
------

      if yield @reference.get_dev_logger()
        @session.dev_logger = true

      @notify state:'incoming-call-carrier-side'

SIP Profile
-----------

Define the (sofia-sip) SIP profiles used to send calls out.

      sip_profile_client = "#{pkg.name}-#{@session.profile}-egress"
      sip_profile_carrier = "#{pkg.name}-#{@session.profile}-ingress"

      @session.sip_profile = @req.variable 'sip_profile'
      if @session.direction is 'ingress'
        @session.sip_profile ?= sip_profile_client
      else
        @session.sip_profile ?= sip_profile_carrier

      @session.transfer = false

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

Note that carrier-side the fields are called `sip_profiles` and are stored in the database.
The FreeSwitch configuration uses the `profiles` field, which defaults to using port 5080.

      @session.profile_data = @cfg.sip_profiles[@session.profile]

Set FreeSwitch variables
------------------------

      sip_params = "xref=#{@session.reference}"
      our_dialplan = "inline:'socket:127.0.0.1:#{@cfg.port ? 5702} async full'"

      yield @set
        session_reference: @session.reference
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

      return
