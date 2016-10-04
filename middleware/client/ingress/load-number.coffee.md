    seem = require 'seem'
    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:ingress:load-number"
    debug = (require 'debug') @name

    @include = seem ->

      return unless @session.direction is 'ingress'

      unless @session.number_domain?
        debug 'Missing session.number_domain'
        return

      @session.number = yield @cfg.prov
        .get "number:#{@destination}@#{@session.number_domain}"
        .catch (error) ->
          debug "number:#{@destination}@#{@session.number_domain} #{error.stack ? error}"
          null

      debug 'OK',
        number: @session.number
      return
