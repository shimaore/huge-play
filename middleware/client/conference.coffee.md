    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:conference"
    seem = require 'seem'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    @include = seem ->

      return unless @session.direction is 'conf'

      unless @cfg.host?
        @debug.dev 'Missing cfg.host'
        return

      unless @session.conf?
        @debug.dev 'Missing conference data'
        return

      conf_name = @conf_name @session.conf

      is_remote = yield @is_remote conf_name, @session.local_server

Conference is remote
--------------------

      if is_remote

        server = is_remote

        uri = "sip:localconf-#{conf_name}@#{server}"

        @debug 'Conference is remote', uri

We use `deflect` (REFER) because this might happen mid-call (for example inside an IVR menu).

        res = yield @action 'deflect', uri

        @debug 'Remote conference returned', uri, res

        return

Conference is handled locally
-----------------------------

      @debug 'Conference is local'

Validate passcode if any.

      language = @session.conf.language
      language ?= @session.language
      language ?= @cfg.announcement_language

      yield @action 'answer'
      yield @set {language}

FIXME: Canonalize from the code already present in well-groomed-feast/middleware/setup

      play_and_get_digits = =>
        @action 'play_and_get_digits', [
          1 # min
          8 # max
          3 # tries
          6000 # timeout
          '#' # terminators
          'phrase:conference:pin' # file
          'phrase:conference:bad_pin' # invalid_file
          'pin'
        ].join ' '

      get_conf_pin = seem =>
        {body} = yield play_and_get_digits()
          .catch (error) =>
            @debug "get_conf_pin: #{error.stack ? error}"
            body: {}
        body.variable_pin

      authenticated = seem =>
        pin = @session.conf.pin
        @debug 'pin', pin
        if not pin?
          return true
        customer_pin = yield get_conf_pin()
          .catch (error) =>
            @debug "pin error: #{error.stack ? error}"
            null
        pin is customer_pin

      if yield authenticated()

        namefile = "/tmp/#{@session.logger_uuid}-name.wav"

This uses `playback`, but `@action 'phrase', 'voicemail_record_name'` (separator is `,` for parameters) should work as well.

        yield @action 'playback', 'phrase:voicemail_record_name'
        @debug 'record'
        yield @action 'record', "#{namefile} 2"

Play in conference
------------------

The thing, really, is that conference uses `switch_core_file` and parses for `say:` only, while `playback` (in `mod_dptools`) uses `switch_ivr_play_file`, which parses `phrase:`, `say:` etc.
Really we should just barge on the channel if we need anything more complex than playing files, tone-streams, etc.

        play_in_conference = (what) =>
          @call.api [
            'conference' # [conference API commands](https://freeswitch.org/confluence/display/FREESWITCH/mod_conference#mod_conference-APIReference)
            conf_name
            'play'
            what
          ].join ' '

        announce = seem =>
          @debug 'announce'
          yield play_in_conference 'tone_stream://%(200,0,500,600,700)'
          # yield play_in_conference 'tone_stream://%(500,0,300,200,100,50,25)'
          yield play_in_conference namefile
          .catch (error) =>
            @debug "error: #{error.stack ? error}"
          # FIXME unlink namefile

        setTimeout announce, 1000

Log into the conference

        @debug 'conference'
        yield @action 'conference', "#{conf_name}++flags{}"
        return
