This module should be called before 'local/carrier-ingress' and before 'client-sbc/$${profile_type}-ingress'

    @name = 'ingress pre (client)'
    @include = ->
      return unless @session.direction is 'ingress'
      @session.ccnq_from_e164 = @source
      @session.ccnq_to_e164 = @destination
