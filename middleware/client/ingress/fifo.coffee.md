    pkg = require '../../../package'
    @name = "#{pkg.name}:middleware:client:ingress:fifo"
    debug = (require 'debug') @name
    seem = require 'seem'

    @description = '''
      Maps an ingress call (which already went through the `local-number` middleware) to a FIFO.
    '''
    @include = ->

      return unless @session.direction is 'ingress'

Check whether we are routing towards a FIFO.

      unless @session.number_domain_data?
        debug 'Missing number_domain_data'
        return

      unless @session.number_domain_data.fifos?
        debug 'Number domain has no FIFOs'
        return

* doc.global_number.local_number To route to a FIFO, this field must contain `fifo-<fifo-number>@<number-domain>`. The fifo-number is typically between 0 and 9; it represents an index in doc.number_domain.fifos.
* doc.number_domain.fifos (array) An array describing the FIFOs in this number-domain, indexed on the fifo-number. Typically the fifo-number is from 0 to 9. See session.fifo for a description of the contents.

      fifo_number = @destination.match(/^fifo-(\d+)$/)?[1]
      return unless fifo_number?
      fifo_number = parseInt fifo_number
      return unless Number.isInteger fifo_number

Move handling to `fifo` middleware.

* session.direction (string) If `fifo`, then the call is handled by a number-domain FIFO. See session.fifo.
* session.fifo (object) The element of doc.number_domain.fifo describing the current FIFO in use.

      @session.direction = 'fifo'
      @session.fifo = @session.number_domain_data.fifos[fifo_number]
      @session.fifo.name ?= "#{fifo_number}"
