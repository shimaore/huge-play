    pkg = require '../package'
    @name = "#{pkg.name}:middleware:setup-fifo"
    debug = (require 'debug') @name
    seem = require 'seem'

    @description = '''
      Add `fifo_member` operation.
    '''
    @include = (ctx) ->

      ctx[k] = v for own k,v of {

Login

        fifo_add: (fifo,source) ->

Logout

        fifo_del: (fifo,source) ->

Build the full fifo name (used inside FreeSwitch) from the short fifo-name and the number-domain.

        fifo_name: (fifo) ->
          "#{@session.number_domain}-#{fifo.name}"
      }
