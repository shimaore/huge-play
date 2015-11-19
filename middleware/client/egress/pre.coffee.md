First-line handler for outbound calls
-------------------------------------

    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:pre"
    debug = (require 'debug') @name

    @include = seem ->

      return unless @session.direction is 'egress'

Endpoint
--------

      @session.endpoint_name = @req.header 'X-CCNQ3-Endpoint'
      unless @session.endpoint_name?
        debug 'Missing endpoint_name'
        return @respond '485 Missing X-CCNQ3-Endpoint'

      debug 'endpoint', @session.endpoint_name

      @session.endpoint = yield @cfg.prov.get "endpoint:#{@session.endpoint_name}"

Outbound-route
--------------

      @session.outbound_route = @session.endpoint.outbound_route
      unless @session.outbound_route?
        debug 'Missing outbound_route'
        return @respond '500 Endpoint has no outbound_route'

      debug 'outbound_route', @session.outbound_route

Number-domain
-------------

      number_domain = @req.header 'X-CCNQ3-Number-Domain'
      number_domain ?= @session.endpoint.number_domain
      unless number_domain?
        debug 'Missing number_domain'
        return @respond '480 Missing Number Domain'
      @session.number_domain = number_domain

      debug 'number_domain', number_domain

Source (calling) number
-----------------------

      src_number = "#{@source}@#{number_domain}"
      @session.number = yield @cfg.prov.get "number:#{src_number}"

      debug 'Ready',
        endpoint_name: @session.endpoint_name
        outbound_route: @session.outbound_route
        number_domain: @session.number_domain

Location
--------

This is needed for emergency call routing.

      location = @session.number.location
      location ?= @session.endpoint.location
      location ?= ''
      yield @set
        'sip_h_X-CCNQ3-Location': location

Privacy
-------

Enforce configurable privacy settings.

      privacy = @session.number.privacy
      privacy = @session.endpoint.privacy
      if privacy
        yield @action 'privacy', 'number'
      else
        yield @action 'privacy', 'no'

Asserted-Number
---------------

Enforce configurable Caller-ID. (Used in particular for ported-in numbers.)

      @session.asserted = @session.number.asserted_number ? @session.endpoint.asserted_number

Check from
----------

Optionally enforce that the calling number originates from the associated endpoint (useful e.g. to prevent invalid caller-id from static endpoints).

      if @session.endpoint.check_from
        if @session.number.endpoint isnt @session.endpoint_name
          debug 'From Username is not listed'
          return @respond '403 From Username is not listed'

      null
