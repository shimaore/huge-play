    @name = 'flat-ornament'
    debug = (require 'debug') @name
    Promise = require 'bluebird'
    Moment = require 'moment-timezone'

    seem = require 'seem'

    run = require 'flat-ornament'

    @include = seem ->

      return unless @session.direction is 'ingress'

* doc.local_number.timezone (string) Local timezone for doc.local_number.ornaments
* session.timezone (string) Local timezone, defaults to doc.local_number.timezone for ingress calls

      @session.timezone ?= @session.number.timezone

Commands
========

* doc.local_number.ornaments: array of ornaments. Each ornament is a list of statements which are executed in order. Each statement contains three fields: `type`: the command to be executed; optional `param` or `params[]`; optional `not` to reverse the outcome of the statement. Valid types include Preconditions: `source(pattern)`: calling number matches pattern; `weekdays(days...)`: current weekday is one of the listed days; `time(start,end)`: current time is between start and end time, in HH:MM format; `anonymous`: caller requested privacy; Postconditions: `busy`, `unavailable`, `no-answer`, `failed`; Actions: `accept`: send call to customer; `reject`: reject call (no announcement); `announce(message)`: reject call with announcement; `voicemail`: send call to voicemail; `forward(destination)`: forward call to destination. Not implemented yet: `email(recipient,template)` and `nighttime`.

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
          @session.direction = 'voicemail'
          'over'

        forward: (destination) =>
          debug 'forward', destination
          @session.reason = 'unspecified'
          @session.direction = 'forward'
          @session.destination = destination
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

        nighttime: =>
          debug 'nighttime'
          # FIXME: check if the @source has nighttime activated
          false

        anonymous: =>
          debug 'anonymous'
          @session.caller_privacy

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
