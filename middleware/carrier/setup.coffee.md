    pkg = require '../../package.json'
    @name = "#{pkg.name}:middleware:carrier:setup"
    debug = (require 'debug') @name

Config
======

    @config = ->

Create the proper profiles and ACLs

      cfg = @cfg

      cfg.host = cfg.prov.get "host:#{cfg.hostname}"
      sip_profiles = @cfg.host.sip_profiles ? {}

      cfg.profiles = {}
      cfg.acls = {}
      for own name,profile of sip_profiles
        ingress = "ingress-#{name}"
        egress = "egress-#{name}"

        cfg.profiles[ingress] =
          sip_port: profile.ingress_sip_port
          sip_ip: profile.ingress_sip_ip
          socket_port: cfg.socket_port ? 5702

        cfg.profiles[egress] =
          sip_port: profile.egress_sip_port ? (profile.ingress_sip_port+10000)
          sip_ip: profile.egress_sip_ip ? profile.ingress_sip_ip
          socket_port: cfg.socket_port ? 5702

        cfg.acls[ingress] = profile.ingress_acl ? []
        cfg.acls[egress] = profile.egress_acl ? []

Server
======

Load the host record so that we can retrieve the `sip_profiles` at runtime.

    @server_pre = ->
      @cfg.host = cfg.prov.get "host:#{cfg.hostname}"
      @cfg.sip_profiles = @cfg.host.sip_profiles ? {}

    @include = ->

First start with the same code as client-side.

      @session.direction = @req.variable 'direction'
      @session.profile = @req.variable 'profile'
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