First-line handler for outbound calls
-------------------------------------
    pkg = require '../package.json'

    @name = "#{pkg.name}/middleware/client/egress/pre"
    debug = (require 'debug') @name
    seem = require 'seem'

    @include = seem ->
      return unless @session.direction is 'egress'

      number_domain = @req.header 'X-CCNQ3-Number-Domain'
      unless number_domain?
        return @respond '480 Missing X-CCNQ3-Number-Domain'
      @session.number_domain = number_domain

      endpoint = @req.header 'X-CCNQ3-Endpoint'
      unless endpoint?
        return @respond '480 Missing X-CCNQ3-Endpoint'
      @session.endpoint = endpoint

      doc = yield @prov.get "endpoint:#{endpoint}"
      @session.endpoint_data = doc
      @session.outbound_route = doc.outbound_route
      unless @session.outbound_route?
        return @respond '500 Endpoint has no outbound_route'
      return

