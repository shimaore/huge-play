    pkg = require '../../package.json'
    @name = "#{pkg.name}:middleware:client:setup"
    debug = (require 'debug') @name

    @include = ->

      @session.direction = @req.variable 'direction'
      @session.profile = @req.variable 'profile'
      @session.sip_profile = @req.variable 'sip_profile'
      if @session.direction is 'ingress'
        @session.sip_profile ?= "#{pkg.name}-#{@session.profile}-egress"
      if @session.direction is 'egress'
        @session.sip_profile ?= "#{pkg.name}-#{@session.profile}-ingress"

      debug 'Ready',
        direction: @session.direction
        profile: @session.profile
        sip_profile: @session.sip_profile
