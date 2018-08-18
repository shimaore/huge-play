    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:conference"
    debug = (require 'tangible') @name
    fs = require 'fs'
    {SUBSCRIBE} = require 'red-rings/operations'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    seconds = 1000
    minutes = 60*seconds

    macros = (cfg) ->
      __count = (name) ->
        cfg.api "conference #{name} get count"

      count = (name) ->
        value = await __count name
        if value.match /^\d+/
          parseInt value, 10
        else
          null

      still_running = (name) ->
        (await count name) is not null

Send NOTIFY messages back anytime the conference is updated.

      notify = (domain,number) ->
        return unless domain? and number?

        conf_name = "#{domain}-conf-#{number}"

        # FIXME only try if local

        list = await cfg
          .api "conference #{conf_name} json_list"
          .catch -> null

        return unless list?
        # and list[0] is '['

        content = try JSON.parse list
        return unless content?

        conf_data = content[0]
        return unless conf_data?

        key = "conference:#{domain}:#{number}"

        cfg.rr.notify key, key, conf_data

      {count,still_running,notify}

    @server_pre = ->

      {notify} = macros @cfg

      @cfg.rr
      .receive 'conference:*'
      .filter ({op}) -> op is SUBSCRIBE
      .forEach (msg) ->
        return unless $ = msg.key?.match /^conference:(\S+):(\d+)$/

        domain = $[1]
        number = $[2]

        notify cfg, domain, number

      return

    @init = ->

      @cfg.record_conference = (name,key,source) =>

        {still_running} = macros @cfg

        debug 'conference:record', name
        recording = await @cfg.api "conference #{name} chkrecord"

Do not start a new recording if one is already active.

        debug 'conference:record: recording', name, recording
        unless recording?.match /is not being recorded/
          debug 'conference:record: Already recording or not ready', name, recording
          return

Get a URL for recording

        unless @cfg.recording_uri?
          debug.dev 'conference:record: Missing recording_uri', name
          return

        metadata = {
          name
          source
          conference_start: new Date().toJSON()
          recording_start: new Date().toJSON()
        }

        uri = await @cfg.recording_uri key, metadata
        await @cfg.api "conference #{name} recording start #{uri}"
        await @cfg.api "conference #{name} play tone_stream://%(125,0,400);%(125,0,450);%(125,0,400)"
        last_uri = uri

        while await still_running name
          await sleep 29*minutes
          metadata.recording_start = new Date().toJSON()
          uri = await @cfg.recording_uri key, metadata
          await @cfg.api "conference #{name} recording start #{uri}"
          await @cfg.api "conference #{name} play tone_stream://%(125,0,400);%(125,0,450);%(125,0,400)"
          await sleep  1*minutes
          await @cfg.api "conference #{name} recording stop #{last_uri}"
          last_uri = uri

        return

      return

    @include = ->

      return unless @session?.direction is 'conf'

      unless @cfg.host?
        debug.dev 'Missing cfg.host'
        return

      unless @session.conf?
        debug.dev 'Missing conference data'
        return

      conf_name = @session.conf.full_name
      if $ = conf_name.match /^(\S+)-conf-(\d+)$/
        domain = $[1]
        number = $[2]
        key = "conference:#{domain}:#{number}"

      is_remote = await @cfg.is_remote conf_name, @session.local_server

Conference is remote
--------------------

      if is_remote

        server = is_remote

        uri = "sip:localconf-#{conf_name}@#{server};xref={@session.reference}"

        debug 'Conference is remote', uri

We use `deflect` (REFER) because this might happen mid-call (for example inside an IVR menu).

        res = await @action 'deflect', uri

        debug 'Remote conference returned', uri, res

        return

Conference is handled locally
-----------------------------

      debug 'Conference is local'

      @notify state:'conference', name:conf_name, key:key

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
        await @set conference_moh_sound: music_uri

Validate passcode if any.

      language = @session.conf.language
      language ?= @session.language
      language ?= @cfg.announcement_language

      await @action 'answer'
      await @set {language}
      await @sleep 2000

      get_conf_pin = (o={}) =>
        @prompt.get_pin
          max: 8
          tries: 3
          timeout: 6000
          file:'phrase:conference:pin'
          invalid_file:'phrase:conference:bad_pin'

      authenticated = =>
        pin = @session.conf.pin
        debug 'pin', pin
        if not pin?
          return true
        customer_pin = await get_conf_pin()
          .catch (error) =>
            debug "pin error: #{error.stack ? error}"
            null
        pin is customer_pin

      if await authenticated()

        namefile = "/tmp/#{@session.logger_uuid}-name.wav"

This uses `playback`, but `@action 'phrase', 'voicemail_record_name'` (separator is `,` for parameters) should work as well.

        await @action 'playback', 'phrase:voicemail_record_name'
        debug 'record'
        await @action 'record', "#{namefile} 2"

Announce number of persons in conference
----------------------------------------

        {count,notify} = macros @cfg

        currently = await count conf_name
        currently ?= 0
        await @action 'playback', "phrase:conference:count:#{currently}"

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

        announce = =>
          debug 'announce'
          await play_in_conference 'tone_stream://%(125,0,300);%(125,0,450);%(125,0,600)'
          await play_in_conference namefile
          .catch (error) =>
            debug "error: #{error.stack ? error}"

        @call.once 'cleanup_linger', =>
          await play_in_conference 'tone_stream://%(125,0,600);%(125,0,450);%(125,0,300)'
          await play_in_conference namefile

          # FIXME: This assumes we are co-located (inside the same container) as FreeSwitch
          # which is stronger than our regular assumption (=we are co-located on the same VM
          # but not in the same container).
          # We should ask FreeSwitch to do the `unlink` here.
          try fs.unlinkSync namefile

          notify domain, number

        setTimeout announce, 1000

        await @set
          conference_max_members: @session.conf.max_members ? null

Log into the conference

        debug 'conference'
        await @reference.set_number_domain @session.number_domain
        @notify state: 'conference:started', name:conf_name, key:key

        notify domain, number

* doc.number_domain.conferences[].record (boolean) If true the conference calls will be recorded.

        if @session.conf.record
          start_recording = =>
            @cfg.record_conference conf_name, key, @source
          setTimeout start_recording, 1000

        await @action 'conference', "#{conf_name}++flags{}"
        return
