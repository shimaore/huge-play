    @name = 'huge-play:middleware:dtmf'
    seem = require 'seem'
    debug = (require 'debug') @name

    @include = ->

      timer = null
      handler = null

      clear_timer = ->
        debug 'clear_timer'
        if timer?
          clearTimeout timer
        timer = null

      clear_handler = =>
        debug 'clear_handler'
        handler = null

      dtmf_buffer = ''

      clear = ->
        debug 'clear'
        clear_handler()
        clear_timer()
        r = dtmf_buffer
        dtmf_buffer = ''
        r

      expect = (min_length, max_length = 16, inter_digit = 3*1000, final = inter_digit) =>
        debug 'expect', min_length, max_length
        clear_timer()

        new Promise (resolve) =>

Clean any post-`#` digits that might be present before we start our timers.

          if m = dtmf_buffer.match /^([^#]*)#/
            clear()
            resolve m[1]
            return

If we already collected enough digits, simply return them.

          if dtmf_buffer.length >= max_length
            resolve clear()
            return

Otherwise we'll have to wait a little bit longer.

          set_timer = ->
            debug 'set timer'
            clear_timer()

First we wait for the inter-digit timeout.

            timer = setTimeout ->
              debug 'inter-digit timer expired'
              clear_timer()

If we waited and the user did not enter a new digit, stop waiting if we already collected the minimum number of digits we needed.

              if dtmf_buffer.length >= min_length
                resolve clear()
                return

Otherwise wait a little longer. If the user does not enter any new digit in the period, return what we have so far (including, possibly, an empty buffer).

              timer = setTimeout ->
                debug 'final timer expired'
                resolve clear()
              , final

              return

            , inter_digit
            return

We start handling new digits arrival.

          handler = ->
            debug 'handler', dtmf_buffer
            clear_timer()

Use `#` as a terminator

            if m = dtmf_buffer.match /^([^#]*)#/
              clear()
              resolve m[1]
              return

When we receive a new digit, if the maximum length is reached we do not wait for another digit.

            if dtmf_buffer.length >= max_length
              resolve clear()
              return

However if we aren't done just yet, simply re-set the timers.

            set_timer()

          set_timer()
          return

      @call.on 'DTMF', (res) =>
        dtmf_buffer ?= ''
        dtmf_buffer += res.body['DTMF-Digit']
        handler? dtmf_buffer
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
          yield @set playback_terminators: '1234567890#*'
          yield @action 'playback', url

`@dtmf.phrase`: execute a phrase command in FreeSwitch, unless a digit has already been entered.

        phrase: seem (phrase) =>
          return if present()
          yield @set playback_terminators: '1234567890#*'
          yield @action 'phrase', phrase

Typical pattern is:
```
# start menu, clear DTMF buffer
@dtmf.clear()
# choice is a Promise that will get resolve once the criteria are met
await @dtmf.playback prompt_file
# expect between one and two digits
switch await @dtmf.expect 1, 2
  when '1'
  when '2'
```

      null

