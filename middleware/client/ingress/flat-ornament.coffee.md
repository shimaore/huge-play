    @name = 'flat-ornament'
    debug = (require 'debug') @name
    Moment = require 'moment-timezone'
    Holidays = require 'date-holidays'

    seem = require 'seem'

    run = require 'flat-ornament'

    @include = seem ->

      return unless @session.direction is 'ingress'
      return if @session.forwarding is true


Note: list IDs are always `<list-name>@<interesting-number>` where the `interesting-number` is the number for which we want to know whether it is whitelisted, blacklisted, etc., while the `list-name` is a unique name for the given list of interesting-numbers.

Returns a list ID for an ingress call.

      local_ingress = seem =>
        list = yield @validate_local_number()
        pid = @req.header 'P-Asserted-Identity'
        interesting_number = if pid? then url.parse(pid).auth else @source
        list_id = "list:#{list}@#{interesting_number}"
        debug 'local_ingress', list, interesting_number
        list_id

Returns a list ID for an egress call.

      local_egress = seem =>
        caller = @session.asserted ? @source
        list = "#{caller}@#{@session.number_domain}"
        interesting_number = @destination
        list_id = "list:#{list}@#{interesting_number}"
        debug 'local_egress', list, interesting_number
        list_id

Global ingress

      global_ingress = seem =>
        unless @session.ccnq_to_164? and @session.ccnq_from_164?
          return false
        list_id = "list:#{@session.ccnq_to_e164}@#{@session.ccnq_from_e164}"

Global egress

      global_egress = seem =>
        unless @session.ccnq_to_164? and @session.ccnq_from_164?
          return false
        list_id = "list:#{@session.ccnq_from_e164}@#{@session.ccnq_to_e164}"

      get_list = seem (list_id) =>
        if list_id
          list = yield @cfg.prov.get(list_id).catch -> {}
          if list.disabled
            null
          else
            list
        else
          null

      is_blacklisted = seem (list_id) =>
        list = yield get_list list_id
        list?.blacklist
      is_whitelisted = seem (list_id) =>
        list = yield get_list list_id
        list?.whitelist
      is_suspicious = seem (list_id) =>
        list = yield get_list list_id
        list?.suspicious

* doc.local_number.timezone (string) Local timezone for doc.local_number.ornaments
* session.timezone (string) Local timezone, defaults to doc.local_number.timezone for ingress calls

      @session.timezone ?= @session.number.timezone

Commands
========

* doc.local_number.ornaments: array of ornaments. Each ornament is a list of statements which are executed in order. Each statement contains three fields: `type`: the command to be executed; optional `param` or `params[]`; optional `not` to reverse the outcome of the statement. Valid types include Preconditions: `source(pattern)`: calling number matches pattern; `weekdays(days...)`: current weekday is one of the listed days; `time(start,end)`: current time is between start and end time, in HH:MM format; `anonymous`: caller requested privacy; `in_calendars([calendars])`: date is in one of the named calendars, stored in doc.number_domain.calendars; Postconditions: `busy`, `unavailable`, `no-answer`, `failed`; Actions: `accept`: send call to customer; `reject`: reject call (no announcement); `announce(message)`: reject call with announcement; `voicemail`: send call to voicemail; `forward(destination)`: forward call to destination. Not implemented yet: `email(recipient,template)` and `nighttime`.
* doc.number_domain.calendars: array or object of calendars. Each calendar is an array of dates in `YYYY-MM-DD` format. The calendars are used as filters by doc.local_number.ornaments' `in_calendars` command.

      commands =

Actions
-------

These actions are terminal for the statement.

        accept: ->
          debug 'accept'
          'over'

        reject: seem =>
          debug 'reject'
          yield @respond '486 Decline'
          'over'

        announce: seem (message) =>
          debug 'announce', message
          yield @action 'answer'
          yield @action 'playback', "#{@cfg.provisioning}/config%3Avoice_prompts/#{message}.wav"
          yield @action 'hangup'
          'over'

        voicemail: =>
          debug 'voicemail'
          @direction 'voicemail'
          'over'

        forward: (destination) =>
          debug 'forward', destination
          @session.reason = 'unspecified'
          @session.destination = destination
          @direction 'forward'
          'over'

Other actions must return `true`.

        email: (recipient,template) =>
          debug 'email', recipient, template
          # FIXME TODO
          true


Preconditions
-------------

These are best used after `post` is used but before `send` is used.

        source: (source) =>
          debug 'source', source
          pattern source, @source

        source_e164: (source) =>
          debug 'source_e164', source
          pattern source, @session.ccnq_from_e164

        destination: (destination) =>
          debug 'destination', destination
          pattern destination, @destination

        destination_e164: (destination) =>
          debug 'destination_e164', destination
          pattern destination, @session.ccnq_to_e164

So, time conditions.
Maybe we first need to figure out in what timezone we are working.
Then get some Date object up and running.

Weekday condition

        weekdays: (days...) =>
          debug 'weekdays', days...
          now = Moment()
          if @session.timezone?
            now = now.tz @session.timezone
          now.day() in days

Time condition

        time: (start,end) =>
          debug 'time', start, end
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

Nightime flag

        nighttime: =>
          debug 'nighttime'
          # FIXME: check if the @source has nighttime activated
          false

Calendars

        in_calendars: (calendars) =>
          debug 'calendars', calendars

          domain_calendars = @session.number_domain_data?.calendars
          return unless domain_calendars?

          now = Moment()
          if @session.timezone?
            now = now.tz @session.timezone
          now_date = new Date now
          now = now.format 'YYYY-MM-DD'

          for calendar in calendars when domain_calendars[calendar]?
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

        anonymous: =>
          debug 'anonymous'
          @session.caller_privacy

        caller_blacklist: -> is_blacklisted local_ingress()
        called_blacklist: -> is_blacklisted local_egress()
        caller_e164_blacklist: -> is_blacklisted global_ingress()
        called_e164_blacklist: -> is_blacklist global_egress()
        caller_whitelist: -> is_whitelisted local_ingress()
        called_whitelist: -> is_whitelisted local_egress()
        caller_e164_whitelist: -> is_whitelisted global_ingress()
        called_e164_whitelist: -> is_whitelist global_egress()
        caller_suspicious: -> is_suspicioused local_ingress()
        called_suspicious: -> is_suspicioused local_egress()
        caller_e164_suspicious: -> is_suspicioused global_ingress()
        called_e164_suspicious: -> is_suspicious global_egress()


Postconditions
--------------

These really only apply after the call has gone through `send` (but probably before it goes through `post-send`.)
They can be used to provide further call treatment, similar to the various `CF..` conditions.

        busy: =>
          debug 'busy'
          @session.reason is 'user-busy'

        unavailable: =>
          debug 'unavailable'
          @session.reason is 'unavailable'

        'no-answer': =>
          debug 'no-anwer'
          @session.reason is 'no-answer'

Notice: `failed` here means the call failed to be sent to the user *and* no other CF.. condition handled it (sending to voicemail using `cfnr_voicemail` is not considered a failure for example).

        failed: =>
          debug 'failed'
          @session.call_failed

        answered: =>
          debug 'answered'
          @has_tag 'answered'

        picked: =>
          debug 'picked'
          @has_tag 'picked'

        transferred: =>
          debug 'transferred'
          @has_tag 'transferred'

Pattern
-------

Does the number `n` match the pattern `p`.

The pattern's `text` field must consists of only:
- digits
- '?' -- replace single of above
- '..' -- replace zero or more

The pattern's `not` field must

      pattern = (p,n) ->

        unless p.match /^(\d|\?|\.\.)+$/
          debug 'invalid pattern', p
          return false

        p = p
          .replace /\.\./g, '\\d*'
          .replace /\?/g, '\\d'

        r = new RegExp "^#{p}$"

        debug 'pattern', p, r

        n.match r

Processing
==========

      yield run.call this, @session.number.ornaments, commands
      return

The ornaments are simply an array of ornaments which are executed in the order of the array.
If any ornament return `true`, skip the remaining ornaments in the list.
