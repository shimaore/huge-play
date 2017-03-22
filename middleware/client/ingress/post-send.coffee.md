    seem = require 'seem'
    @name = "huge-play:middleware:client:ingress:post-send"
    debug = (require 'debug') @name

    @include = seem ->

      return unless @session.direction is 'ingress'

      debug 'Ready'

Make sure the call isn't processed any further.

      delete @session.direction

Rewrite error response code.

      if @session.call_failed
        debug 'Call Failed'
        yield @respond '486 Call Failed'
        return

      if @session.was_transferred
        debug 'Was Transferred'
        return

      if @session.was_picked
        debug 'Was Picked'
        return

      debug 'Hangup'
      @tag 'hangup'
      yield @action 'hangup'
