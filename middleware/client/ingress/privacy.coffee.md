    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:privacy"
    debug = (require 'tangible') @name

    @include = ->

      return unless @session?.direction is 'ingress'

      debug 'Ready'

Handle privacy request
======================

Privacy: id or other requested privacy

      if @data['Caller-Privacy-Hide-Number'] is 'true'
        debug 'Privacy requested'
        @source = 'anonymous'
        await @action 'privacy', 'full'
        await @set
          effective_caller_id_name: '_undef_'
          effective_caller_id_number: 'anonymous'
          origination_privacy: 'screen+hide_name+hide_number'

Source anonymous, either because of Privacy: id (above) or already set.

      if @source is 'anonymous'
        @session.caller_privacy = true

      debug 'OK'
      return
