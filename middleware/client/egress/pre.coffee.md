First-line handler for outbound calls
-------------------------------------

    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}/middleware/client/egress/pre"
    debug = (require 'debug') @name

    @include = seem ->

      return unless @session.direction is 'egress'

      @session.endpoint_name = @req.header 'X-CCNQ3-Endpoint'
      unless @session.endpoint_name?
        return @respond '485 Missing X-CCNQ3-Endpoint'
      @session.endpoint = yield @prov.get "endpoint:#{@session.endpoint_name}"

      @session.outbound_route = @session.endpoint.outbound_route
      unless @session.outbound_route?
        return @respond '500 Endpoint has no outbound_route'
      return

      number_domain = @req.header 'X-CCNQ3-Number-Domain'
      number_domain ?= @session.endpoint.number_domain
      unless number_domain?
        return @respond '480 Missing Number Domain'
      @session.number_domain = number_domain

      src_number = "#{@source}@#{number_domain}"
      @session.number = yield @prov.get "number:#{src_number}"

Upcoming changes

      ###
      if @session.endpoint.privacy
        Privacy: id
      if @session.number.privacy
        Privacy: id
      if @dession.endpoint.asserted_number
        P-Asserted-Identity: <#{@session.endpoint_data.asserted_number}>@#{from_domain}
      if @dession.number.asserted_number
        P-Asserted-Identity: <#{@session.endpoint_data.asserted_number}>@#{from_domain}
      ###

      if @session.endpoint.check_from
        if @session.number.endpoint isnt @session.endpoint_name
          @respond '403 From Username is not listed'
