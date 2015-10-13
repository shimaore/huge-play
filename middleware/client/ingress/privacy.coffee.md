    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:privacy"
    debug = (require 'debug') @name

    @include = seem ->

      return unless @session.direction is 'ingress'

      debug 'Ready'

Handle privacy request
======================

Privacy: id or other requested privacy

      if @data['Caller-Privacy-Hide-Number'] is 'true'
        debug 'Privacy requested'
        @source = 'anonymous'
        yield @action 'privacy', 'full'
        yield @set
          effective_caller_id_name: '_undef_'
          effective_caller_id_number: 'anonymous'
          origination_privacy: 'screen+hide_name+hide_number'

        @session.caller_privacy = true

      debug 'OK'
      return
