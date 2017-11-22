    @name = 'huge-play:middleware:dtmf'
    seem = require 'seem'
    debug = (require 'tangible') @name

    @include = seem ->

      timer = null
      handler = null

      dtmf_buffer = ''

      on_change = null

      yield @call.event_json 'DTMF'
      @call.on 'DTMF', (res) =>
        c = res.body['DTMF-Digit']
        debug "Received #{c}"
        dtmf_buffer ?= ''
        dtmf_buffer += c
        on_change?()
        return

      wait_for_digit = (timeout) =>
        if on_change?
          debug.dev "wait_for_digit called while already active (ignore)"
          return Promise.reject new Error 'recursive'

        new Promise (resolve,reject) =>

          on_timeout = =>
            on_change = null
            reject new Error 'timeout'

          timer = setTimeout on_timeout, timeout

          on_change = ->
            on_change = null
            clearTimeout timer
            resolve()

          return

      expect = seem (min_length = 1, max_length = min_length, inter_digit = 3*1000) =>
        debug 'expect', min_length, max_length, inter_digit

        clear = (r = dtmf_buffer) ->
          debug 'clear'
          dtmf_buffer = ''
          if r.length < min_length
            ''
          else
            r.substr 0, max_length

        while true

If the user already provide a value, terminated with `#`,

          if m = dtmf_buffer.match /^([^#]*)#/

then use that value.

            return clear m[1]

Make sure we don't overflow.

          if dtmf_buffer.length >= max_length
            return clear()

Wait for a digit

          try

            yield wait_for_digit inter_digit

If we didn't collect a digit,

          catch error

do we already have enough?

            return clear()

        return

      present = ->
        dtmf_buffer.length > 0

Public API
----------

      @dtmf =

`@dtmf.clear`: resets all fields. If the buffer was not empty, returns the content of the buffer.

        clear: ->
          [r,dtmf_buffer] = [dtmf_buffer,'']
          r

`@dtmf.expect min, max, inter_digit`: Returns a Promise that will resolve once at least `min` (default: 1) and at most `max` (default: `min`) digits have been received, with an inter-digit timeout of `inter_digit` (in ms, default: 3000). If the number of collected digits is not enough, return the empty string.

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
# play the prompt
await @dtmf.playback prompt_file
# expect between one and two digits
switch await @dtmf.expect 1, 2
  when '1'
  when '2'
```

      null
