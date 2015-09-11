    pkg = require '../../../package'
    @name = "#{pkg.name}/middleware/carrier/egress/pre"
    @include = ->
      return unless @session.direction is 'ingress'

      @set
        ccnq_direction: @session.direction
        ccnq_profile: @session.profile
        ccnq_from_e164: @source
        ccnq_to_e164: @destination
        progress_timeout: 12
        call_timeout: 300
        t38_passthru: true
