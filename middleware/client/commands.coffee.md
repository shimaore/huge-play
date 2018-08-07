    @name = 'huge-play:middleware:client:commands'
    debug = (require 'tangible') @name
    Moment = require 'moment-timezone'
    Holidays = require 'date-holidays'
    request = require 'superagent'
    compile = require 'flat-ornament/compile'
    serialize = require 'useful-wind-serialize'

    max_menu_depth = 42

Lists handling
==============

`list:` ID manufacture
----------------------

Note: list IDs are always `<list-name>@<interesting-number>` where the `interesting-number` is the number for which we want to know whether it is whitelisted, blacklisted, etc., while the `list-name` is a unique name for the given list of interesting-numbers.

List ID for an ingress call.

    local_ingress = ->
      list = await @validate_local_number()
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

    get_list = (list_id) ->
      if list_id
        list = await @cfg.prov.get(list_id).catch -> {}
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
      ->
        list_id = await selector.call this
        list = await get_list.call this, list_id
        test.call this, list

Commands
========

* doc.number_domain.calendars: array or object of calendars. Each calendar is an array of dates in `YYYY-MM-DD` format. The calendars are used as filters by doc.local_number.ornaments' `in_calendars` command.

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

      hangup: ->
        @debug 'hangup'
        await @action 'hangup'
        @direction 'hangup'
        'over'

      send: (destination) ->
        @debug 'send'
        @session.direction = 'ingress'
        @destination = destination
        await serialize.modules ingress_modules, this, 'include'
        'over'

`menu_send`: send the call to the (ingress) destination keyed (must be a number in the current number-domain)

      menu_send: ->
        @debug 'menu_send'
        return false unless @menu?
        await @menu.expect()
        @debug 'menu_send', @menu.value
        @session.direction = 'ingress'
        @destination = @menu.value
        await serialize.modules [menu_conference_module,ingress_modules...], this, 'include'
        'over'

      reject: ->
        @debug 'reject'
        await @respond '486 Decline'
        'over'

      announce: (message) ->
        @debug 'announce', message
        await @action 'answer'
        await @action 'playback', "#{@cfg.provisioning}/config%3Avoice_prompts/#{message}.wav"
        await @action 'hangup'
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

      play: (file) ->
        @debug 'play', file
        url = @prompt.uri 'prov', 'ignore', @session.number_domain_data._id, file
        await @action 'answer'
        await @unset 'playback_terminators'
        await @action 'playback', url
        true

      message: (number) ->
        @debug 'message', number
        return true unless @session.number_domain_data?.msg?[number]?.active
        file = "msg-#{number}.mp3"
        url = @prompt.uri 'prov', 'ignore', @session.number_domain_data._id, file
        await @action 'answer'
        await @unset 'playback_terminators'
        await @action 'playback', url
        true

`menu_play`: play a file, stop playing when a key is pressed

      menu_play: (file) ->
        @debug 'menu_play', file
        url = @prompt.uri 'prov', 'ignore', @session.number_domain_data._id, file
        await @action 'answer'
        await @dtmf.playback url
        true

`music`: set the music-on-hold

      music: (file) ->
        @session.music = @prompt.uri 'prov', 'ignore', @session.number_domain_data._id, file
        true

`ringback`: set the ringback

      ringback: (file) ->
        @session.ringback = @prompt.uri 'prov', 'ignore', @session.number_domain_data._id, file
        true

      wait: (ms) ->
        @debug 'wait', ms
        await @dtmf.playback "silence_stream://#{ms}"
        @debug 'wait over', ms
        true

      record: (name) ->
        @record_call "#{@session.number_domain_data._id}:#{name}"

Preconditions
-------------

These are best used after `post` is used but before `send` is used.
These can also be used (in more recent script languages) to retrieve the named value.

      source: (source) ->
        @debug 'source', source
        if source?
          pattern source, @source
        else
          @source

      source_e164: (source) ->
        @debug 'source_e164', source
        if source?
          pattern source, @session.ccnq_from_e164
        else
          @session.ccnq_from_e164

      destination: (destination) ->
        @debug 'destination', destination
        if destination?
          pattern destination, @destination
        else
          @destination

      destination_e164: (destination) ->
        @debug 'destination_e164', destination
        if destination?
          pattern destination, @session.ccnq_to_e164
        else
          @session.ccnq_to_e164

So, time conditions.
Maybe we first need to figure out in what timezone we are working.
Then get some Date object up and running.

Weekday condition

      weekdays: (days...) ->
        @debug 'weekdays', days...
        now = Moment()
        if @session.timezone?
          now = now.tz @session.timezone
        now = now.day()
        if days.length > 0
          now in days
        else
          now

Time condition

      time: (start,end) ->
        @debug 'time', start, end
        now = Moment()
        if @session.timezone?
          now = now.tz @session.timezone

        now = now.format 'HH:mm'

        unless start? and end?
          return now

start: '09:00', end: '17:00'

        if start <= end
          start <= now <= end

start: '18:00', end: '08:00'

        else
          start <= now or now <= end

More call commands, mostly call-center
--------------------------------------

      user_tag: (tag) ->
        @user_tag tag
        @notify state:'menu', user_tag:tag
        true

      alert_info: (alert_info) ->
        await @export {alert_info}
        @session.alert_info = alert_info
        true

      clear_call_center_tags: ->
        await @clear_call_center_tags()
        true

      clear_user_tags: ->
        await @clear_user_tags()
        true

      required_skill: (skill) ->
        await @tag "skill:#{skill}"
        true

      priority: (priority) ->
        await @tag "priority:#{priority}"
        true

      queue: (queue) ->
        await @tag "queue:#{queue}"
        true

      broadcast: ->
        await @tag 'broadcast'
        true

      has_tag: (tag) ->
        @has_tag tag

      has_user_tag: (tag) ->
        @has_user_tag tag

      has_skill: (skill) ->
        @has_tag "skill:#{skill}"

      has_queue: (queue) ->
        @has_tag "queue:#{queue}"

Agent commands (only applicable in `login_ornaments`)
--------------

      agent_skill: (skill) ->
        return false unless typeof skill is 'string'
        await @agent.add_tag "skill:#{skill}"
        true

      agent_queue: (queue) ->
        return false unless typeof queue is 'string'
        await @agent.add_tag "queue:#{queue}"
        true

      agent_has_skill: (skill) ->
        @agent.has_tag "skill:#{skill}"

      agent_has_queue: (queue) ->
        @agent.has_tag "queue:#{queue}"

Calendars

      in_calendars: (calendars...) ->
        @debug 'calendars', calendars

Legacy format: only one argument and that argument is an array.

        if calendars.length is 1 and typeof calendars[0] not in ['string','number']
          calendars = calendars[0]

        domain_calendars = @session.number_domain_data?.calendars ? {}

        now = Moment()
        if @session.timezone?
          now = now.tz @session.timezone
        now_date = new Date now
        now = now.format 'YYYY-MM-DD'

        for calendar in calendars
          switch

            when m = calendar.toString().match /^_holidays_(.*)$/
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
              if domain_calendars[calendar]?
                {dates} = domain_calendars[calendar]
                if dates? and now in dates
                  return true
        false

      anonymous: ->
        @debug 'anonymous'
        @session.caller_privacy

      webhook: (uri) ->
        @debug 'webhook'
        try
          {body} = await request
            .post uri
            .send
              tags: await @reference.tags()
              ccnq_from_e164: @session.ccnq_from_e164
              ccnq_to_e164: @session.ccnq_to_e164
              _in: @_in()
          if body?
            await @user_tags body.tags
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

`menu`: start collecting digits for a menu; digits received before this command are discarded.

      menu: ( min = 1, max = min, itd ) ->
        @debug 'menu_start'
        await @action 'answer'
        @dtmf.clear()
        @menu =
          expect: =>
            @menu.value ?= await @dtmf.expect min, max, itd
        true

`menu_on`: true if the user keyed the choice

      menu_on: (choice) ->
        choice = "#{choice}"
        @debug 'menu_on', choice
        return false unless @menu?
        await @menu.expect()
        @debug 'menu_on', choice, @menu.value
        @menu.value is choice

      goto_menu: (number) ->
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

        await @sleep 200
        fun = compile item, @ornaments_commands
        await fun.call this if fun?
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
