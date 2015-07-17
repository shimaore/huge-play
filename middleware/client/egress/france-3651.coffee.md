    @include = ->

      return unless @session.direction is 'egress'
      return unless @session.dialplan is 'national'
      return unless @session.country is 'fr'

      if m = @res.destination.match /^3651(\d+)$/
        @destination = m[1]

Add a `Privacy: id` header.

        @action 'privacy', 'number'
