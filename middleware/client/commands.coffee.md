    @name = 'huge-play:middleware:client:commands'
    debug = (require 'tangible') @name
    Moment = require 'moment-timezone'
    Holidays = require 'date-holidays'
    request = require 'superagent'
    run = require 'flat-ornament'
    seem = require 'seem'
    serialize = require 'useful-wind-serialize'

    max_menu_depth = 42

Lists handling
==============

`list:` ID manufacture
----------------------

Note: list IDs are always `<list-name>@<interesting-number>` where the `interesting-number` is the number for which we want to know whether it is whitelisted, blacklisted, etc., while the `list-name` is a unique name for the given list of interesting-numbers.

List ID for an ingress call.

    local_ingress = seem ->
      list = yield @validate_local_number()
      pid = @req.header 'P-Asserted-Identity'
      interesting_number = if pid? then url.parse(pid).auth else @source
      list_id = "list:#{list}@#{interesting_number}"
      @debug 'local_ingress', list, interesting_number
      list_id

List ID for an egress call.

    local_egress = ->
      caller = @session.asserted ? @source
      list = "#{caller}@#{@session.number_domain}"
      interesting_number = @destination
      list_id = "list:#{list}@#{interesting_number}"
      @debug 'local_egress', list, interesting_number
      list_id

Global ingress

    global_ingress = ->
      unless @session.ccnq_to_164? and @session.ccnq_from_164?
        return false
      list_id = "list:#{@session.ccnq_to_e164}@#{@session.ccnq_from_e164}"

Global egress

    global_egress = ->
      unless @session.ccnq_to_164? and @session.ccnq_from_164?
        return false
      list_id = "list:#{@session.ccnq_from_e164}@#{@session.ccnq_to_e164}"

List retriever
--------------

    get_list = seem (list_id) ->
      if list_id
        list = yield @cfg.prov.get(list_id).catch -> {}
        if list.disabled
          null
        else
          list
      else
        null

List status
-----------

    is_blacklisted = (list) ->
      list?.blacklist
    is_whitelisted = (list) ->
      list?.whitelist
    is_suspicious = (list) ->
      list?.suspicious

Commands builder
----------------

    chain = (test,selector) ->
      seem ->
        list_id = yield selector.call this
        list = yield get_list.call this, list_id
        test.call this, list

Commands
========

* doc.number_domain.calendars: array or object of calendars. Each calendar is an array of dates in `YYYY-MM-DD` format. The calendars are used as filters by doc.local_number.ornaments' `in_calendars` command.

FIXME Allow for modules using us to specify which module(s) to run in case of menu-send.

    menu_conference_module =
      name: 'menu_conference_module'
      include: ->
        return unless @session.dialplan is 'centrex'
        return unless m = @destination.match /^82(\d+)$/
        number = parseInt m[1], 10
        item = @session.number_domain_data?.conferences?[number]
        if item?
          item.short_name ?= "conf-#{number}"
          item.full_name ?= "#{@session.number_domain}-#{item.short_name}"
          @session.conf = item
          @direction 'conf'
        return

    ingress_modules = [
    ]

    module.exports = commands =

Actions
-------

These actions are terminal for the statement.

      stop: ->
        @debug 'stop'
        'over'

      accept: ->
        @debug 'accept'
        'over'

      hangup: seem ->
        @debug 'hangup'
        yield @action 'hangup'
        @direction 'hangup'
        'over'

      send: seem (destination) ->
        @debug 'send'
        @session.direction = 'ingress'
        @destination = destination
        yield serialize.modules ingress_modules, this, 'include'
        'over'

`menu_send`: send the call to the (ingress) destination keyed (must be a number in the current number-domain)

      menu_send: seem ->
        @debug 'menu_send'
        return false unless @menu?
        yield @menu.expect()
        @debug 'menu_send', @menu.value
        @session.direction = 'ingress'
        @destination = @menu.value
        yield serialize.modules [menu_conference_module,ingress_modules...], this, 'include'
        'over'

      reject: seem ->
        @debug 'reject'
        yield @respond '486 Decline'
        'over'

      announce: seem (message) ->
        @debug 'announce', message
        yield @action 'answer'
        yield @action 'playback', "#{@cfg.provisioning}/config%3Avoice_prompts/#{message}.wav"
        yield @action 'hangup'
        'over'

      voicemail: ->
        @debug 'voicemail'
        @direction 'voicemail'
        'over'

      forward: (destination) ->
        @debug 'forward', destination
        @session.reason = 'unspecified'
        @session.destination = destination
        @direction 'forward'
        'over'

Other actions must return `true`.

      email: (recipient,template) ->
        @debug 'email', recipient, template
        # FIXME TODO
        true

`play`: play a file, uninterrupted (should be used for short prompts)

      play: seem (file) ->
        @debug 'play', file
        url = @prompt.uri 'prov', 'ignore', @session.number_domain_data._id, file
        yield @action 'answer'
        yield @unset 'playback_terminators'
        yield @action 'playback', url
        true

`menu_play`: play a file, stop playing when a key is pressed

      menu_play: seem (file) ->
        @debug 'menu_play', file
        url = @prompt.uri 'prov', 'ignore', @session.number_domain_data._id, file
        yield @action 'answer'
        yield @dtmf.playback url
        true

      wait: seem (ms) ->
        @debug 'wait', ms
        yield @dtmf.playback "silence_stream://#{ms}"
        @debug 'wait over', ms
        true

      record: (name) ->
        @record_call name

Preconditions
-------------

These are best used after `post` is used but before `send` is used.

      source: (source) ->
        @debug 'source', source
        pattern source, @source

      source_e164: (source) ->
        @debug 'source_e164', source
        pattern source, @session.ccnq_from_e164

      destination: (destination) ->
        @debug 'destination', destination
        pattern destination, @destination

      destination_e164: (destination) ->
        @debug 'destination_e164', destination
        pattern destination, @session.ccnq_to_e164

So, time conditions.
Maybe we first need to figure out in what timezone we are working.
Then get some Date object up and running.

Weekday condition

      weekdays: (days...) ->
        @debug 'weekdays', days...
        now = Moment()
        if @session.timezone?
          now = now.tz @session.timezone
        now.day() in days

Time condition

      time: (start,end) ->
        @debug 'time', start, end
        now = Moment()
        if @session.timezone?
          now = now.tz @session.timezone

        now = now.format 'HH:mm'

start: '09:00', end: '17:00'

        if start <= end
          start <= now <= end

start: '18:00', end: '08:00'

        else
          start <= now or now <= end

      user_tag: (tag) ->
        @user_tag tag
        @notify state:'menu', user_tag:tag
        true

      alert_info: seem (alert_info) ->
        yield @export {alert_info}
        @session.alert_info = alert_info
        true

      clear_call_center_tags: seem ->
        yield @clear_call_center_tags()
        true

      clear_user_tags: seem ->
        yield @clear_user_tags()
        true

      required_skill: seem (skill) ->
        yield @tag "skill:#{skill}"
        true

      priority: seem (priority) ->
        yield @tag "priority:#{priority}"
        true

      queue: seem (queue) ->
        yield @tag "queue:#{queue}"
        true

      multi: seem ->
        yield @tag 'multi'
        true

      has_tag: (tag) ->
        @has_tag tag

      has_user_tag: (tag) ->
        @has_user_tag tag

Calendars

      in_calendars: (calendars) ->
        @debug 'calendars', calendars

        if 'string' is typeof calendars
          calendars = [calendars]

        domain_calendars = @session.number_domain_data?.calendars ? {}

        now = Moment()
        if @session.timezone?
          now = now.tz @session.timezone
        now_date = new Date now
        now = now.format 'YYYY-MM-DD'

        for calendar in calendars
          switch

            when m = calendar.match /^_holidays_(.*)$/
              hd = new Holidays()
              hd.init.apply hd, m[1].split '_'
              res = hd.isHoliday now_date
              if res?.type is 'public'
                return true

            when calendar is '_holidays'
              if @session.country
                hd = new Holidays @session.country.toUpperCase()
                res = hd.isHoliday now_date
                if res?.type is 'public'
                  return true

            else
              if calendar of domain_calendars
                {dates} = domain_calendars[calendar]
                if dates? and now in dates
                  return true
        false

      anonymous: ->
        @debug 'anonymous'
        @session.caller_privacy

      webhook: seem (uri) ->
        @debug 'webhook'
        try
          {body} = yield request
            .post uri
            .send
              tags: yield @reference.tags()
              ccnq_from_e164: @session.ccnq_from_e164
              ccnq_to_e164: @session.ccnq_to_e164
              _in: @_in()
          if body?
            yield @user_tags body.tags
          true
        catch
          @debug 'webhook: error'
          false

Postconditions
--------------

These really only apply after the call has gone through `send` (but probably before it goes through `post-send`.)
They can be used to provide further call treatment, similar to the various `CF..` conditions.

      busy: ->
        @debug 'busy'
        @session.reason is 'user-busy'

      unavailable: ->
        @debug 'unavailable'
        @session.reason is 'unavailable'

      'no-answer': ->
        @debug 'no-anwer'
        @session.reason is 'no-answer'

Notice: `failed` here means the call failed to be sent to the user *and* no other CF.. condition handled it (sending to voicemail using `cfnr_voicemail` is not considered a failure for example).

      failed: ->
        @debug 'failed'
        @session.call_failed

      answered: ->
        @debug 'answered'
        if @session.was_connected then true else false

      picked: ->
        @debug 'picked'
        if @session.was_picked then true else false

      transferred: ->
        @debug 'transferred'
        if @session.was_transferred then true else false

      caller_blacklist:       chain is_blacklisted, local_ingress
      called_blacklist:       chain is_blacklisted, local_egress
      caller_e164_blacklist:  chain is_blacklisted, global_ingress
      called_e164_blacklist:  chain is_blacklisted, global_egress
      caller_whitelist:       chain is_whitelisted, local_ingress
      called_whitelist:       chain is_whitelisted, local_egress
      caller_e164_whitelist:  chain is_whitelisted, global_ingress
      called_e164_whitelist:  chain is_whitelisted, global_egress
      caller_suspicious:      chain is_suspicious, local_ingress
      called_suspicious:      chain is_suspicious, local_egress
      caller_e164_suspicious: chain is_suspicious, global_ingress
      called_e164_suspicious: chain is_suspicious, global_egress

Menus
-----

`menu_start`: start collecting digits for a menu; digits received before this command are discarded.

      menu: seem ( min = 1, max = min, itd ) ->
        @debug 'menu_start'
        yield @action 'answer'
        @dtmf.clear()
        @menu =
          expect: seem =>
            @menu.value ?= yield @dtmf.expect min, max, itd
        true

`menu_on`: true if the user keyed the choice

      menu_on: seem (choice) ->
        choice = "#{choice}"
        @debug 'menu_on', choice
        return false unless @menu?
        yield @menu.expect()
        @debug 'menu_on', choice, @menu.value
        @menu.value is choice

      goto_menu: seem (number) ->
        @debug 'goto_menu', number

Copying the logic from middleware/client/ingress/fifo

        type = 'menu'
        items = @session.number_domain_data.menus
        unless items?
          @debug.csr "Number domain has no data for #{type}."
          return
        unless items.hasOwnProperty number
          @debug.dev "No property #{number} in #{type} of #{@session.number_domain}"
          return
        item = items[number]
        unless item?
          @debug.csr "Number domain as no data #{number} for #{type}."
          return
        @session[type] = item
        @direction type

        @debug "Using #{type} #{number}", item

        @menu_depth ?= 0
        @menu_depth++
        if @menu_depth > max_menu_depth
          return false

        yield @sleep 200
        yield run.call this, item, @ornaments_commands
        'over'

Pattern
-------

Does the number `n` match the pattern `p`.

The pattern must consists of only:
- digits
- '?', '.' -- replace single of above
- '..', '...', '…' -- replace zero or more

    pattern = (p,n) ->

      unless p.match /^(\d|\?|\.|\.\.|\.\.\.|…)+$/
        debug 'invalid pattern', p
        return false

      p = p
        .replace /\.\.|\.\.\.|…/g, '\\d*'
        .replace /\?|\./g, '\\d'

      r = new RegExp "^#{p}$"

      debug 'pattern', p, r

      n.match r
