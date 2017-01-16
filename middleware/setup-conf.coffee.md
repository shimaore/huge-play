    pkg = require '../package'
    @name = "#{pkg.name}:middleware:setup-conf"
    seem = require 'seem'

    @include = (ctx) ->

      ctx[k] = v for own k,v of {
        conf_name: (conf) ->
          "#{@session.number_domain}-#{conf.name}"
      }
