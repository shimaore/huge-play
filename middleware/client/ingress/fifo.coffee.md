    pkg = require '../../../package'
    @name = "#{pkg.name}:middleware:client:ingress:fifo"
    seem = require 'seem'

    @description = '''
      Maps an ingress call (which already went through the `local-number` middleware) to a FIFO/conference/menu.
    '''
    @include = ->

      return unless @session.direction is 'ingress'

We won't be able to route if there is no number-domain data.

      unless @session.number_domain_data?
        @debug.dev 'Missing number_domain_data'
        return

* doc.global_number.local_number To route to a FIFO, this field must contain `fifo-<fifo-number>@<number-domain>`. The fifo-number is typically between 0 and 9; it represents an index in doc.number_domain.fifos.
* doc.number_domain.fifos (array) An array describing the FIFOs in this number-domain, indexed on the fifo-number. Typically the fifo-number is from 0 to 9. See session.fifo for a description of the contents.
* doc.global_number.local_number To route to a menu, this field must contain `menu-<menu-number>@<number-domain>`. The menu-number is typically between 0 and 9; it represents an index in doc.number_domain.menus.
* doc.number_domain.menus (array) An array describing the menus in this number-domain, indexed on the menu-number. Typically the menu-number is from 0 to 9. See session.menu for a description of the contents.
* doc.global_number.local_number To route to a conference, this field must contain `conf-<conf-number>@<number-domain>`. The conf-number is typically between 0 and 9; it represents an index in doc.number_domain.conferences.
* doc.number_domain.conferences (array) An array describing the conferences in this number-domain, indexed on the conf-number. Typically the conf-number is from 0 to 9. See session.conf for a description of the contents.

      @debug "Testing for FIFO/conference/menu in #{@destination}"

      m = @destination.match /^(fifo|conf|menu)-(\d+)$/

      type = m[1]

      items = switch type
        when 'fifo'
          @session.number_domain_data.fifos
        when 'conf'
          @session.number_domain_data.conferences
        when 'menu'
          @session.number_domain_data.menus
        else # Huh?
          null

      unless items?
        @debug.csr "Number domain has no data for #{type}."
        return

      number = m[2]
      return unless number?
      number = parseInt number
      return unless Number.isInteger number

Move handling to `fifo` middleware.

* session.direction (string) If `fifo`, then the call is handled by a number-domain FIFO. See session.fifo.
* session.fifo (object) The element of doc.number_domain.fifos describing the current FIFO in use.

      item = items[number]
      unless item?
        @debug.csr "Number domain has no data #{number} for #{type}."
        return

      item.name ?= "#{number}"
      @session.direction = type
      @session[type] = item

      @debug "Using #{type} #{number}", item
