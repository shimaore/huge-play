    seem = require 'seem'
    @name = 'privacy-ingress'
    @include = seem ->

      return unless @session.direction is 'ingress'

Handle privacy request
======================

Privacy: id or other requested privacy

TODO: populate `@session.privacy_hide_number`

      if @data['Caller-Privacy-Hide-Number'] is 'true'
        @source = 'anonymous'
        yield @action 'privacy', 'full'
        yield @set
          effective_caller_id_name: '_undef_'
          effective_caller_id_number: 'anonymous'
          origination_privacy: 'screen+hide_name+hide_number'
