    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:post-forward"
    debug = (require 'debug') @name

Call-Handler
============

This is a simplified version of the `middleware/client/ingress/post` handler.
Its only purpose is to route Centrex internal forwarded calls.
All attributes set on the initial call are kept as much as possible.

    @include = seem ->

      return unless @session.direction is 'ingress'
      return unless @session.forwarding is true

      debug 'Ready',
        dialplan: @session.dialplan
        country: @session.country
        destination: @destination
        number_domain: @session.number_domain

      if @session.dialplan is 'e164'
        return @respond '484'

      dst_number = yield @validate_local_number()

      yield set_params.call this

Build the destination FreeSwitch dialstring
-------------------------------------------

      parameters = []
      to_uri = "sip:#{@session.endpoint_name}"

      unless to_uri.match /@/
        to_uri = "sip:#{@destination}@#{@cfg.ingress_target}"

      if @session.number.endpoint_via?
        parameters.push "sip_network_destination=#{@session.number.endpoint_via}"

      @session.initial_destinations ?= [
        { parameters, to_uri }
      ]

      @tag 'post-forward'

### Build the set of `_in` targets for notifications of the reference data.

      @session.reference_data._in ?= []
      @_in @session.reference_data._in
      yield @save_ref()

      debug 'Done.'
      return

`set_params`
============

Most parameters have been set before the forwarding happened.
We only tweak a few things for the actual destination endpoint.

    set_params = seem ->
      debug 'set_params'

      dlg_timeout = @session.number.dialog_timer ? 28000 # 8h

      debug 'schedule hangup'
      yield @action 'sched_hangup', "+#{dlg_timeout}"

      yield @export
        'sip_h_X-CCNQ3-Number-Domain': @session.number_domain
        'sip_h_X-CCNQ3-Endpoint': @session.endpoint_name

      debug 'set_params: done.'
      return
