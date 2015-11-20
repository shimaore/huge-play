    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:post-send"
    debug = (require 'debug') @name

    @include = ->

      return unless @session.direction is 'ingress'

      debug 'Ready'

      if @session.call_failed
        return @respond '486 Call Failed'

      @action 'hangup'
