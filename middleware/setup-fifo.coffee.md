    pkg = require '../package'
    @name = "#{pkg.name}:middleware:setup-fifo"
    debug = (require 'debug') @name
    seem = require 'seem'

    @description = '''
      Add `fifo_member` operation.
    '''
    @include = (ctx) ->

      ctx[k] = v for own k,v of {
        fifo_add: seem (fifo,member) =>
          str = yield member_string fifo, member
          debug "Adding member #{member} to #{fifo.name} as #{str}"
          yield @call.api "fifo_member add #{str}"

        fifo_del: seem (fifo,member) =>
          str = yield member_string fifo, member
          debug "Removing member #{member} from #{fifo.name} as #{str}"
          yield @call.api "fifo_member del #{str}"

Build the full fifo name (used inside FreeSwitch) from the short fifo-name and the number-domain.

        fifo_name: (fifo) =>
          "#{@session.number_domain}-#{fifo.name}"
      }

Member String
-------------

Members are on-system agents. We locate the matching local-number and build the dial-string from there.
We only support `endpoint_via` and `cfg.ingress_target` for locating members.

      member_string = seem (fifo,member) =>
        debug "fifo member_string #{member}@#{@session.number_domain}"

        fifo_name = @fifo_name fifo

Locate FIFO member

        member_data = yield @cfg.prov
          .get "number:#{member}@#{@session.number_domain}"
          .catch (error) ->
            debug "number:#{member}@#{@session.number_domain} : #{error.stack ? error}"
            {}

This is a simplified version of the sofia-string building code found in middleware:client:ingress:send.

        destination = member_data.number.split('@')[0]
        target = member_data.endpoint_via ? @cfg.ingress_target
        uri = "sip:#{destination}@#{target}"
        sofia = "sofia/#{@session.sip_profile}/#{uri}"

        params = [
          'fifo_member_wait=nowait'
          "sip_h_X-CCNQ3-Endpoint=#{member_data.endpoint}"
          "sip_h_X-CCNQ3-Number-Domain=#{@session.number_domain}"
        ]

        "#{fifo_name} {#{params.join ','}}#{sofia}"
