    pkg = require '../../../package'
    @name = "#{pkg.name}:middleware:client:ingress:fifo"
    seem = require 'seem'

    @description = '''
      Maps an ingress call (which already went through the `local-number` middleware) to a FIFO/conference/menu.
    '''
    @include = seem ->

      return unless @session.direction is 'ingress'

      @debug "Testing for FIFO/conference/menu in #{@destination}"

      m = @destination.match /^(fifo|conf|menu|localconf)-(.+)$/
      return unless m?

      type = m[1]
      number = m[2]
      return unless number?

The `localconf` type is used by other servers to transfer calls for conferences which are served on this server. (See [`../conference`](../conference.coffee.md).)
In this case the conference name is the number-domain and the conference name.

      if type is 'localconf' and not @session.number_domain_data?
        conf_name = number
        m = conf_name.match /^(.+)-([^-]+)$/
        unless m?
          @debug.dev "localconf #{m} is not properly formatted"
          return

        type = 'conf'
        number_domain = m[1]
        number = m[2]

        @session.number_domain = number_domain
        @session.number_domain_data = yield @cfg.prov
          .get "number_domain:#{number_domain}"
          .catch (error) =>
            @debug.dev "number_domain #{number_domain}: #{error}"
            null
        @tag @session.number_domain_data._id
        @user_tags @session.number_domain_data.tags

        if @session.number_domain_data?.timezone?
          @session.timezone ?= @session.number_domain_data?.timezone

We won't be able to route if there is no number-domain data.

      unless @session.number_domain_data?
        @debug.dev 'Missing number_domain_data'
        return
      @tag @session.number_domain_data._id

* doc.global_number.local_number To route to a FIFO, this field must contain `fifo-<fifo-number>@<number-domain>`. The fifo-number is typically between 0 and 9; it represents an index in doc.number_domain.fifos.
* doc.number_domain.fifos (array) An array describing the FIFOs in this number-domain, indexed on the fifo-number. Typically the fifo-number is from 0 to 9. See session.fifo for a description of the contents.
* doc.global_number.local_number To route to a menu, this field must contain `menu-<menu-number>@<number-domain>`. The menu-number is typically between 0 and 9; it represents an index in doc.number_domain.menus.
* doc.number_domain.menus (array) An array describing the menus in this number-domain, indexed on the menu-number. Typically the menu-number is from 0 to 9. See session.menu for a description of the contents.
* doc.global_number.local_number To route to a conference, this field must contain `conf-<conf-number>@<number-domain>`. The conf-number is typically between 0 and 9; it represents an index in doc.number_domain.conferences.
* doc.number_domain.conferences (array) An array describing the conferences in this number-domain, indexed on the conf-number. Typically the conf-number is from 0 to 9. See session.conf for a description of the contents.

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

Move handling to `fifo` middleware.

* session.direction (string) If `fifo`, then the call is handled by a number-domain FIFO. See session.fifo.
* session.fifo (object) The element of doc.number_domain.fifos describing the current FIFO in use.

      unless items.hasOwnProperty number
        @debug.dev "No property #{number} in #{type} of #{@session.number_domain}."
        return

      item = items[number]
      @tag "#{type} number #{number}"
      unless item?
        @debug.csr "Number domain has no data #{number} for #{type}."
        return

These are also found in middleware/client/egress/fifo.

      item.short_name ?= "#{type}-#{number}"
      if type is 'conf'
        item.full_name ?= "#{@session.number_domain}-#{item.short_name}"
      else
        item.full_name ?= "#{item.short_name}@#{@session.number_domain}"
      @session[type] = item
      @direction type
      @report state:type

      @debug "Using #{type} #{number}", item
