    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:centrex-redirect"

    @include = seem ->

      return unless @session.direction is 'egress'
      return unless @session.dialplan is 'centrex'

Transfer Workaround
-------------------

      is_remote = yield @is_remote @session.number_domain, [@session.local_server,@session.client_server].join '/'

      if is_remote
        server = is_remote.split('/')[1]

        uri = "sip:#{@destination}@#{server}"
        @debug 'Handling is remote', uri

Send a REFER to a call which is already answered. (Typically, coming from `exultant-songs`.)

        if @data['Answer-State'] is 'answered'
          res = yield @action 'deflect', uri

For an unanswered call (the default/normal behavior for a call coming from a phone),
send a 302 back to OpenSIPS; OpenSIPS interprets the 302 and submits to the remote server.

        else
          res = yield @action 'redirect', uri

        @debug 'Redirection returned', uri, res

Make sure there is no further processing.

        @direction 'transfered'
        return

Centrex Handling
----------------

      @debug 'Handling is local'
