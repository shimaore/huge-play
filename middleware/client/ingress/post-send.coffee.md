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

Do not hangup here. If the call was transfered this might cause it to disconnect.
