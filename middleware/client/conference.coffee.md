    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:conference"
    seem = require 'seem'

    @include = seem ->

      return unless @session.direction is 'conference'

      unless @session.conf?
        @debug.dev 'Missing conference data'
        return

      conf_name = @conf_name conf

Use redis to retrieve the server on which this conference is hosted.

      key = "conf server #{conf_name}"

      server = yield @redis
        .get
        .catch -> null

      unless server?
        server = @cfg.host
        yield @redis.set key, server

Conference is local (assuming FreeSwitch is co-hosted, which is our standard assumption).

      if server is @cfg.host

Validate passcode if any.

        yield @action 'conference', "#{conf_name}+#{conf.passcode}+flags{}"


Conference is remote.

      else

        yield @action 'deflect', "#{@destination}@#{server}"
