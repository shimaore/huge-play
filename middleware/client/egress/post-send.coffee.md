    seem = require 'seem'
    @name = "huge-play:middleware:client:egress:post-send"

    @include = seem ->

      return unless @session.direction is 'egress'

      @debug 'Ready'

Make sure the call isn't processed any further.

      delete @session.direction

The only post-call action currently is to hangup the call.

      @debug 'Hangup'
      @notify state: 'hangup'
      yield @action 'hangup'
