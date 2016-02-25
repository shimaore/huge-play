    @name = 'flat-ornament'
    debug = (require 'debug') @name
    Promise = require 'bluebird'
    Moment = require 'moment-timezone'

    seem = require 'seem'

    @include = seem ->

      return unless @session.direction is 'ingress'

* doc.local_number.timezone (string) Local timezone for doc.local_number.ornaments
* session.timezone (string) Local timezone, defaults to doc.local_number.timezone for ingress calls

      @session.timezone ?= @session.number.timezone

Execute
-------

Each ornament is a list of statements which are executed in order.
A statement consists of:
- a `type` (the command to be executed);
- optional `param` or `params[]` (parameters for the command);
- optional `not` (to reverse the outcome).
Execution continues as long as the outcome of a statement is true.

Normally conditions are listed first, while actions are listed last, but really we don't care.

Applying `not` to an action probably won't do what you expect.

      execute = seem (ornament) =>

        for statement in ornament
          c = commands[statement.type]

Terminate the statement if the command is invalid.

          return unless c?

Otherwise terminate the statement if the command returns true (normal case) or false (if `not` is present).

          switch
            when ornament.params?
              truth = yield c.apply this, ornament.params
            when ornament.param?
              truth = yield c.apply this, ornament.param
            else
              truth = yield c.apply this

          truth = not truth if statement.not

          return unless truth

Commands
========

* doc.local_number.ornaments: array of ornaments. Each ornament is a list of statements which are executed in order. Each statement contains three fields: `type`: the command to be executed; optional `param` or `params[]`; optional `not` to reverse the outcome of the statement. Valid types include Preconditions: `source(pattern)`: calling number matches pattern; `weekdays(days...)`: current weekday is one of the listed days; `time(start,end)`: current time is between start and end time, in HH:MM format; `anonymous`: caller requested privacy; Postconditions: `busy`, `unavailable`, `no-answer`, `failed`; Actions: `accept`: send call to customer; `reject`: reject call (no announcement); `announce(message)`: reject call with announcement; `voicemail`: send call to voicemail; `forward(destination)`: forward call to destination. Not implemented yet: `email(recipient,template)` and `nighttime`.

      commands =

Actions
-------

These actions are terminal for the statement and return `false`.
(Use `not` to make them non-terminal, although that probably won't do what you expect.)

        accept: ->
          debug 'accept'
          over = true
          false

        reject: seem ->
          debug 'reject'
          yield @respond '486 Decline'
          false

        announce: seem (message) ->
          debug 'announce', message
          over = true
          yield @action 'answer'
          yield @action 'playback', "#{@cfg.provisioning}/config%3Avoice_prompts/#{message}.wav"
          yield @action 'hangup'
          false

        voicemail: ->
          debug 'voicemail'
          over = true
          @session.direction = 'voicemail'
          false

        forward: (destination) ->
          debug 'forward'
          over = true
          @session.reason = 'unspecified'
          @session.direction = 'forward'
          @session.destination = destination
          false

Other actions must return `true`.

        email: (recipient,template) ->
          debug 'email', recipient, template
          # FIXME TODO
          true


Preconditions
-------------

These are best used after `post` is used but before `send` is used.

        source: (source) ->
          debug 'source', source
          pattern source, @source

So, time conditions.
Maybe we first need to figure out in what timezone we are working.
Then get some Date object up and running.

Weekday condition

        weekdays: (days...) ->
          debug 'weekdays', days...
          now = Moment()
          if @session.timezone?
            now = now.tz @session.timezone
          now.weekday() in days

Time condition

        time: (start,end) ->
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

        nighttime: ->
          # FIXME: check if the @source has nighttime activated
          false

        anonymous: ->
          @session.caller_privacy

Postconditions
--------------

These really only apply after the call has gone through `send` (but probably before it goes through `post-send`.)
They can be used to provide further call treatment, similar to the various `CF..` conditions.

        busy: ->
          @session.reason is 'user-busy'

        unavailable: ->
          @session.reason is 'unavailable'

        'no-answer': ->
          @session.reason is 'no-answer'

Notice: `failed` here means the call failed to be sent to the user *and* no other CF.. condition handled it (sending to voicemail using `cfnr_voicemail` is not considered a failure for example).

        failed: ->
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

        debug 'invalid pattern', p unless p.match /^(\d|\?|\.\.)+$/

        p.replace /\.\./g, '\d*'
        p.replace /\?/g, '\d'

        r = new RegExp "^#{p}$"

        n.match r

Processing
==========

      ornaments = @session.number.ornaments

      return unless ornaments?

      debug 'Processing'

The ornaments are simply an array of ornaments which are executed in the order of the array.

      over = false

      for ornament in ornaments
        return if over
        yield do (ornament) => execute ornament

      return
