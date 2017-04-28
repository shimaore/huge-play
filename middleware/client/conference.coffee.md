    pkg = require '../../package'
    @name = "#{pkg.name}:middleware:client:conference"
    seem = require 'seem'

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

        is_remote = yield @cfg.is_remote name, local_server

        endpoint_data = yield @prov.get "endpoint:#{endpoint}"

        {account} = endpoint_data
        calling_number = endpoint.asserted_number

Call it out

        params = make_params
          origination_caller_id_number: calling_number
          'sip_h_P-Charge-Info': account
          'sip_h_X-CCNQ3-Endpoint': endpoint

        yield @api "conference #{name} dial {#{params}}sofia/#{profile}/#{destination}@#{host}:#{port}"

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
          # FIXME unlink namefile

        setTimeout announce, 1000

        yield @set
          conference_max_members: @session.conf.max_members ? null

Log into the conference

        @debug 'conference'
        yield @action 'conference', "#{conf_name}++flags{}"
        return
