    pkg = require '../../../package.json'
    seem = require 'seem'
    @name = "#{pkg.name}:middleware:client:forward:basic-post"
    debug = (require 'tangible') @name

    @include = seem ->

      return unless @session?.direction is 'egress'
      return unless @session.forwarding is true

      yield @action 'hangup'
      return
