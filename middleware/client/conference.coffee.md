    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:conference"
    debug = (require 'tangible') @name
    seem = require 'seem'
    fs = require 'fs'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    seconds = 1000
    minutes = 60*seconds

    macros = (cfg) ->
      __count = (name) ->
        cfg.api "conference #{name} get count"

      count = seem (name) ->
        value = yield __count name
        if value.match /^\d+/
          parseInt value, 10
        else
          null

      still_running = seem (name) ->
        (yield count name) is not null

      {count,still_running}

    @init = ->

      @cfg.statistics.on 'conference:record', seem (name) =>

        {still_running} = macros @cfg

        debug 'conference:record', name
        recording = yield @cfg.api "conference #{name} chkrecord"

Do not start a new recording if one is already active.

        debug 'conference:record: recording', name, recording
        unless recording?.match /is not being recorded/
          debug 'conference:record: Already recording or not ready', name, recording
          return

Get a URL for recording

        unless @cfg.recording_uri?
          debug.dev 'conference:record: Missing recording_uri', name
          return

        uri = yield @cfg.recording_uri name
        yield @cfg.api "conference #{name} recording start #{uri}"
        yield @cfg.api "conference #{name} play tone_stream://%(125,0,400);%(125,0,450);%(125,0,400)"
        last_uri = uri

        while yield still_running name
          yield sleep 29*minutes
          uri = yield @cfg.recording_uri name
          yield @cfg.api "conference #{name} recording start #{uri}"
          yield @cfg.api "conference #{name} play tone_stream://%(125,0,400);%(125,0,450);%(125,0,400)"
          yield sleep  1*minutes
          yield @cfg.api "conference #{name} recording stop #{last_uri}"
          last_uri = uri

        return

    @notify = ->

      @configure dial_calls: true
      @register 'conference:get-participants', 'dial_calls'
      @register 'conference:participants', 'calls'

      @socket.on 'conference:get-participants', seem (conf_name) =>
        debug 'conference:get-participants', conf_name

        # FIXME this is magic
        return unless $ = conf_name.match /^(\S+)-conf-\d+$/

        domain = $[1]

        # FIXME only try if local

        list = yield @cfg
          .api "conference #{conf_name} json_list"
          .catch -> null

        return unless list?
        # and list[0] is '['

        content = try JSON.parse list
        return unless content?

        conf_data = content[0]
        return unless conf_data?

        conf_data._in = [
          "number_domain:#{domain}"
          "conference:#{conf_name}"
        ]

        @socket.emit 'conference:participants', conf_data

    @include = seem ->

      return unless @session.direction is 'conf'

      unless @cfg.host?
        @debug.dev 'Missing cfg.host'
        return

      unless @session.conf?
        @debug.dev 'Missing conference data'
        return

      conf_name = @session.conf.full_name

      is_remote = yield @cfg.is_remote conf_name, @session.local_server

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

      @notify state:'conference', name:conf_name

      conf_uri = (id,name) =>
        @prompt.uri 'prov', 'prov', id, name

      id = "number_domain:#{@session.number_domain}"

      if @session.music?
        music_uri = @session.music
      if @session.conf.music?
        if @session.conf.music is false
          music_uri = null
        else
          music_uri = conf_uri id, @session.conf.music
      if music_uri?
        yield @set conference_moh_sound: music_uri

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

Announce number of persons in conference
----------------------------------------

        {count} = macros @cfg

        currently = yield count conf_name
        currently ?= 0
        yield @action 'playback', "phrase:conference:count:#{currently}"

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

        @call.once 'cleanup_linger'
        .then =>
          yield play_in_conference 'tone_stream://%(125,0,600);%(125,0,450);%(125,0,300)'
          yield play_in_conference namefile

          # FIXME: This assumes we are co-located (inside the same container) as FreeSwitch
          # which is stronger than our regular assumption (=we are co-located on the same VM
          # but not in the same container).
          # We should ask FreeSwitch to do the `unlink` here.
          try fs.unlinkSync namefile

        setTimeout announce, 1000

        yield @set
          conference_max_members: @session.conf.max_members ? null

Log into the conference

        @debug 'conference'
        yield @reference.add_in "number_domain:#{@session.number_domain}"
        # yield @reference.add_in "conference:#{conf_name}"
        @notify state: 'conference:started', conference: conf_name

* doc.number_domain.conferences[].record (boolean) If true the conference calls will be recorded.

        if @session.conf.record
          start_recording = =>
            @cfg.statistics.emit 'conference:record', conf_name
          setTimeout start_recording, 1000

        yield @action 'conference', "#{conf_name}++flags{}"
        return
