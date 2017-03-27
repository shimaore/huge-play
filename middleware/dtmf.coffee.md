    @name = 'huge-play:middleware:dtmf'
    seem = require 'seem'

    @include = seem ->

      yield @set playback_terminators: '1234567890#*'

      inter_digit_timer = null
      final_timer = null

      clear_timers = ->
        if inter_digit_timer?
          clearTimeout inter_digit_timer
        inter_digit_timer = null
        if final_timer?
          clearTimeout final_timer
        final_timer = null

      dtmf_buffer = ''

      clear = ->
        clear_timers()
        r = dtmf_buffer
        dtmf_buffer = ''
        r

      expect = (min_length, max_length = 16, inter_digit = 3*1000, timeout = 7*1000) =>
        clear()
        clear_timers()

        new Promise (resolve) =>

          set_timers = ->
            clear_timers()
            inter_digit_timer = setTimeout ->

If we waited and the user did not enter a new digit, stop waiting if we already collected enough digits.

              if dtmf_buffer.length >= min_length
                resolve clear()

Otherwise wait a little longer. If the user does not enter any new digit in the period, return what we have so far.

              setTimeout ->
                resolve clear()
              , timeout
            , inter_digit

          @call.on 'dtmf_buffer', ->
            debug "dtmf_buffer = `#{dtmf_buffer}`"
            clear_timers()

When we receive a new digit, if the maximum length is reached we do not wait for another digit.

            if dtmf_buffer.length >= max_length
              resolve clear()
              return

            set_timers()

          set_timers()

        return

      @call.on 'DTMF', (res) =>
        dtmf_buffer ?= ''
        dtmf_buffer += res.body['DTMF-Digit']
        @call.emit 'dtmf_buffer', dtmf_buffer
        return

      present = ->
        dtmf_buffer.length > 0

Public API
----------

      @dtmf =

`@dtmf.clear`: resets all fields. If the buffer was not empty, returns the content of the buffer.

        clear: clear

`@dtmf.expect min, max, inter_digit, final`: Returns a Promise that will resolve once at least `min` (default: 1) and at most `max` (default: 16) digits have been received, with an inter-digit timeout of `inter_digit` (in ms, default: 3000) and a final timeout `final` (in ms, default: 7000). Note that the total waiting time is `inter_digit+final`.

        expect: expect

`@dtmf.playback`: execute a playback command in FreeSwitch, unless a digit has already been entered.

        playback: seem (url) =>
          return if present()
          @action 'playback', url

`@dtmf.phrase`: execute a phrase command in FreeSwitch, unless a digit has already been entered.

        phrase: seem (phrase) =>
          return if present()
          @action 'phrase', phrase

Typical pattern is:
```
# expect between one and two digits
choice = @dtmf.expect 1, 2
# choice is a Promise that will get resolve once the criteria are met
await @dtmf.playback prompt_file
switch await choice
  when '1'
  when '2'
```

      null

