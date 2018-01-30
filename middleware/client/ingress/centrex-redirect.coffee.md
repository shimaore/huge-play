    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:centrex-redirect"

    @include = seem ->

      return unless @session?.direction is 'ingress'
      return unless @session.dialplan is 'centrex'

Transfer Workaround
-------------------

      is_remote = yield @cfg.is_remote @session.number_domain, [@session.local_server,@session.client_server].join '/'

      if is_remote
        server = is_remote.split('/')[0]
        @report {state:'centrex-redirect', server}

        uri = "<sip:#{@session.ccnq_to_e164}@#{server};xref=#{@session.reference}>"
        @debug 'Handling is remote', uri

Send a REFER to the carrier-side SBC.

        res = yield @action 'deflect', uri
        @debug 'Redirection returned', uri, res

Make sure there is no further processing.

        @direction 'transferred'
        return

Centrex Handling
----------------

Monitor the a-leg.

      if @cfg.queuer? and @queuer_call?
        queuer_call = yield @queuer_call()
        yield @cfg.queuer.monitor_remote_call queuer_call

      @debug 'Handling is local'
