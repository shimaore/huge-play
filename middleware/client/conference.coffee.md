    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:conference"
    seem = require 'seem'

    seconds = 1000
    minutes = 60*seconds

    @server_pre = ->

      @cfg.statistics.on 'start-conference', seem (name) =>

        still_running = seem =>
          (yield @api "conference #{name} get count").match /^\d+/

        @debug 'start-conference', name
        recording = yield @api "conference #{name} chkrecord"

Do not start a new recording if one is already active.

        return unless recording.match /is not being recorded/

Get a URL for recording

        return unless @cfg.recording_uri?

        uri = yield @cfg.recording_uri name
        yield @api "conference #{name} start #{uri}"
        last_uri = uri

        while yield still_running()
          yield sleep 29*minutes
          uri = yield @cfg.recording_uri name
          yield @api "conference #{name} start #{uri}"
          yield sleep  1*minutes
          yield @api "conference #{name} stop #{last_uri}"
          last_uri = uri

        return

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

        uri = "sip:localconf-#{conf_name}@#{server};xref={@session.reference}"

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
      yield @sleep 2000

      get_conf_pin = (o={}) =>
        @prompt.get_pin
          max: 8
          tries: 3
          timeout: 6000
          file:'phrase:conference:pin'
          invalid_file:'phrase:conference:bad_pin'

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
          yield play_in_conference 'tone_stream://%(125,0,300);%(125,0,450);%(125,0,600)'
          yield play_in_conference namefile
          .catch (error) =>
            @debug "error: #{error.stack ? error}"
          # FIXME unlink namefile

        setTimeout announce, 1000

Log into the conference

        @debug 'conference'
        @cfg.statistics.emit 'start-conference', conf_name
        yield @action 'conference', "#{conf_name}++flags{}"
        return
