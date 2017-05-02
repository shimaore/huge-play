    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:conference"
    seem = require 'seem'
    fs = require 'fs'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

Duplicated in tough-rate, black-metal, `sofia_string`, … (FIXME)

    escape = (v) ->
      "#{v}".replace ',', ','

    make_params = (data) ->
      ("#{k}=#{escape v}" for own k,v of data).join ','

    @notify = ->

Duplicated from middleware/client/queuer (FIXME)

      profile = @cfg.session?.profile
      host = @cfg.host
      p = @cfg.profiles?[profile]
      if p?
        port = p.egress_sip_port ? p.sip_port+10000

Note: if there are multiple profiles in use we will get in trouble at that point.

        local_server = "#{@cfg.host}:#{p.ingress_sip_port ? p.sip_port}"

      @socket.on 'add-to-conference', seem ({name,endpoint,destination}) =>
        @debug 'add-to-conference', name, endpoint, destination

        is_remote = yield @cfg.is_remote name, local_server

        endpoint_data = yield @prov.get "endpoint:#{endpoint}"

        {account} = endpoint_data
        calling_number = endpoint.asserted_number

Call it out

        params = make_params
          origination_caller_id_number: calling_number
          'sip_h_P-Charge-Info': account
          'sip_h_X-CCNQ3-Endpoint': endpoint

        yield @cfg.api "conference #{name} dial {#{params}}sofia/#{profile}/#{destination}@#{host}:#{port}"

    seconds = 1000
    minutes = 60*seconds

    @server_pre = ->

      @cfg.statistics.on 'record-conference', seem (name) =>

        still_running = seem =>
          (yield @cfg.api "conference #{name} get count")?.match /^\d+/

        @debug 'record-conference', name
        recording = yield @cfg.api "conference #{name} chkrecord"

Do not start a new recording if one is already active.

        @debug 'record-conference: recording', name, recording
        unless recording?.match /is not being recorded/
          @debug 'Already recording or not ready'
          return

Get a URL for recording

        unless @cfg.recording_uri?
          @debug.dev 'Missing recording_uri', name
          return

        uri = yield @cfg.recording_uri name
        yield @cfg.api "conference #{name} start #{uri}"
        yield @cfg.api "conference #{name} play tone_stream://%(125,0,400);%(125,0,450);%(125,0,400)"
        last_uri = uri

        while yield still_running()
          yield sleep 29*minutes
          uri = yield @cfg.recording_uri name
          yield @cfg.api "conference #{name} start #{uri}"
          yield @cfg.api "conference #{name} play tone_stream://%(125,0,400);%(125,0,450);%(125,0,400)"
          yield sleep  1*minutes
          yield @cfg.api "conference #{name} stop #{last_uri}"
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
        @cfg.statistics.emit 'start-conference', conf_name

* doc.number_domain.conferences[].record (boolean) If true the conference calls will be recorded.

        if @session.conf.record
          start_recording = =>
            @cfg.statistics.emit 'record-conference', conf_name
          setTimeout start_recording, 1000

        yield @action 'conference', "#{conf_name}++flags{}"
        return
