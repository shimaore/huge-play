    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:post-send"
    debug = (require 'debug') @name

    @include = ->

      return unless @session.direction is 'egress'

      debug 'Ready'

The only post-call action currently is to hangup the call.

      @action 'hangup'
