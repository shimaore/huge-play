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

Send a 302 back to OpenSIPS; OpenSIPS interprets the 302 and submits to the remote server.

        res = yield @action 'redirect', uri
        @debug 'Redirection returned', uri, res
        return

Centrex Handling
----------------

      @debug 'Handling is local'
