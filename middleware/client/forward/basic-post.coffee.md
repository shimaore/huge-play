    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:forward:basic-post"
    debug = (require 'tangible') @name

    @include = ->

      return unless @session?.direction is 'egress'
      return unless @session.forwarding is true

      await @action 'hangup'
      return
