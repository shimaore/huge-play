    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:centrex-CH"
    debug = (require 'tangible') @name

    @include = ->

      return unless @session?.direction is 'egress'
      return unless @session.dialplan is 'centrex'
      return unless @session.country is 'ch'

      debug 'Start'

      @session.centrex_external_line_prefix = '9'
      @session.VOICEMAIL = '786'

      switch

Internal call: ring the phone, apply cfa/cfb/cfda/cfnr if applicable.
Keep @session.dialplan.

        when @destination.match /^[1-6]\d+$/
          debug 'Internal call'
          await @action 'privacy', 'no'
          @session.centrex_internal = true
          @session.sip_profile = @session.sip_profile_client
          @direction 'ingress'
          @session.cdr_direction = 'centrex-internal'
          return

External call.
For Centrex we use `asserted` as `egress calling number`, and only use it for external calls.
Keep @session.direction and @session.country.

        when @destination[0] is @session.centrex_external_line_prefix and m = @destination.match /^\d(\d+)$/
          debug 'External call'
          @session.dialplan = 'national'
          @destination = m[1]
          @source = @session.asserted ? @session.number.asserted ? @source
          debug 'External call', {@source,@destination}
          return

        when @destination[0] is '+'
          @session.dialplan = 'national'
          @source = @session.asserted ? @session.number.asserted ? @source
          debug 'External call', {@source,@destination}
          return

Voicemail.

        when @destination in ['vm','voicemail','*86','786']
          debug 'Voicemail'
          @destination = 'inbox'
          @direction 'voicemail'
          return
