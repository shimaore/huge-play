    pkg = require '../../package.json'
    @name = "#{pkg.name}:middleware:carrier:setup"
    debug = (require 'debug') @name
    seem = require 'seem'
    assert = require 'assert'

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
            .catch (error) ->
              debug "Host #{cfg.host}: #{error}"
              {}
        else
          debug 'No cfg.host'
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
            .catch (error) ->
              debug "Host #{cfg.host}: #{error}"
              {}
        else
          debug 'No cfg.host'
          {}

      @cfg.sip_profiles ?= @cfg.host_data.sip_profiles ? {}

      debug 'Configuring SIP Profiles', @cfg.sip_profiles
      null

    @include = ->

First start with the same code as client-side.

      context = @data['Channel-Context']
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

      @session.profile_data = @cfg.sip_profiles[@session.profile]

      debug 'Ready',
        direction: @session.direction
        profile: @session.profile
        sip_profile: @session.sip_profile

      return
