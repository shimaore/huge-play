    @name = 'flat-ornament'
    debug = (require 'debug') @name
    Promise = require 'bluebird'
    Moment = require 'moment-timezone'

    seem = require 'seem'

    @include = seem ->

      return unless @session.direction is 'ingress'

      ornaments = @session.number.ornaments

      return unless ornaments?

      debug 'Processing'

An ornament is a list of rules which are evaluated in order. Each rule consists of a preconditions and an action. If the precondition is met, the action is processed.

      over = false

      for ornament in ornaments
        return if over
        yield do (ornament) => execute ornament

Execute
-------

Each ornament is a list of statements, really.
A statement consists of:
- a `type`
- optional `param` or `params[]`.
- optional `not` (to reverse the outcome).

Normally conditions are listed first, while actions are listed last, but really we don't care.

Applying `not` to an action probably won't do what you expect.

      execute = seem (ornament) =>

        for statement in ornament
          c = commands[statement.type]

Fail the statement if the command is invalid.

          return unless c?
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

      commands =

Actions
-------

These actions are terminal for the statement and return `false`.

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
