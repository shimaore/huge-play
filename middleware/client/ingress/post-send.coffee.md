    seem = require 'seem'
    @name = "huge-play:middleware:client:ingress:post-send"

    @include = seem ->

      return unless @session?.direction is 'ingress'

      @debug 'Ready'

Make sure the call isn't processed any further.

      delete @session.direction

Rewrite error response code.

      switch
        when @session.call_failed
          @debug 'Call Failed'
          @notify state:'call-failed'
          yield @respond '486 Call Failed'

        when @session.was_transferred
          @notify state:'call-was-transferred'
          @debug 'Was Transferred'

        when @session.was_picked
          @notify state:'call-was-picked'
          @debug 'Was Picked'

        else
          @debug 'Hangup'
          @notify state:'hangup'
          yield @action 'hangup'
