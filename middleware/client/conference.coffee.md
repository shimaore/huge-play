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

Use redis to retrieve the server on which this conference is hosted.

      server = @cfg.host

Set if not exists, [setnx](https://redis.io/commands/setnx)
(Note: there's also hsetnx/hget which could be used for this, not sure what's best practices.)

      key = "conference server for #{conf_name}"

      existing = yield @redis
        .setnxAsync key, server
        .catch -> null

      if existing
        server = yield @redis
          .getAsync key
          .catch -> null

Conference is local (assuming FreeSwitch is co-hosted, which is our standard assumption).

      if server is @cfg.host

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
          yield @action 'playback', 'phrase:voicemail_record_name'
          @debug 'record'
          yield @action 'record', "#{namefile} 2"

          play_in_conference = (what) =>
            @call.api [
              'conference' # [conference API commands](https://freeswitch.org/confluence/display/FREESWITCH/mod_conference#mod_conference-APIReference)
              conf_name
              'play'
              what
            ].join ' '

          announce = =>
            @debug 'announce'
            play_in_conference "conference:has_joined:#{namefile}"
            .catch (error) =>
              @debug "error: #{error.stack ? error}"

          setTimeout announce, 1000

Log into the conference

          @debug 'conference'
          yield @action 'conference', "#{conf_name}++flags{}"

Conference is remote.

      else

        yield @action 'deflect', "#{@destination}@#{server}"
