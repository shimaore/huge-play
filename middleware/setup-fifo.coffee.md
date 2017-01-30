    pkg = require '../package'
    @name = "#{pkg.name}:middleware:setup-fifo"
    debug = (require 'debug') @name
    seem = require 'seem'

    @description = '''
      Add `fifo_member` operation.
    '''
    @include = (ctx) ->

      ctx[k] = v for own k,v of {
        fifo_add: seem (fifo,member) ->
          str = yield member_string fifo, member
          debug "Adding member #{member} to #{fifo.name} as #{str}"
          # FIXME TBD
          new Promise()

        fifo_del: seem (fifo,member) ->
          str = yield member_string fifo, member
          debug "Removing member #{member} from #{fifo.name} as #{str}"
          # FIXME TBD
          new Promise()

Build the full fifo name (used inside FreeSwitch) from the short fifo-name and the number-domain.

        fifo_name: (fifo) ->
          "#{@session.number_domain}-#{fifo.name}"
      }

Member String
-------------

Members are on-system agents. We locate the matching local-number and build the dial-string from there.
We only support `endpoint_via` and `cfg.ingress_target` for locating members.

      member_string = seem (fifo,member) =>
        debug "fifo member_string #{member}@#{@session.number_domain}"

        fifo_name = @fifo_name fifo

        fifo_sofia = yield @sofia_string member, [
          'fifo_member_wait=nowait' # Hangup call when call hangs up
        ]
        "#{fifo_name} #{fifo_sofia}"
