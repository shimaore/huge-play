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

      server = @cfg.host

Set if not exists, [setnx](https://redis.io/commands/setnx)
(Note: there's also hsetnx/hget which could be used for this, not sure what's best practices.)

      key = "conference server for #{conf_name}"

      existing = yield @redis
        .setnxAsync key, server
        .catch -> null

      if existing
        server = yield @redis
          .getAsync key
          .catch -> null

Conference is local (assuming FreeSwitch is co-hosted, which is our standard assumption).

      if server is @cfg.host

Validate passcode if any.

        yield @action 'conference', "#{conf_name}+#{conf.passcode}+flags{}"

Conference is remote.

      else

        yield @action 'deflect', "#{@destination}@#{server}"
