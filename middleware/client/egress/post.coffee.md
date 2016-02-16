    seem = require 'seem'
    url = require 'url'

    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:post"
    debug = (require 'debug') @name
    assert = require 'assert'

    default_music = 'tone_stream://%(300,10000,440);loops=-1'

    @include = seem ->
      return unless @session.direction is 'egress'

      debug 'Ready'

      unless @session.ccnq_from_e164? and @session.ccnq_to_e164?
        debug 'Missing e164 numbers'
        return @respond '484'

      @session.e164_number = yield @cfg.prov.get("number:#{@session.ccnq_from_e164}").catch -> {}

      if @session.e164_number.fs_variables?
        yield @set @session.e164_number.fs_variables

The URL module parses the SIP username as `auth`.

      pci = @req.header 'P-Charge-Info'
      unless pci?
        debug 'No Charge-Info'
        return @respond '403 No Charge-Info'

      @session.ccnq_account = (url.parse pci).auth
      unless @session.ccnq_account?
        debug 'Invalid Charge-Info', pci
        return @respond '403 Invalid Charge-Info'

Settings for calling number (see middleware/client/ingress/post.coffee.md):

      if @session.number.custom_music is true
        @session.music ?= [
          @cfg.userdb_base_uri
          @session.number.user_database
          'voicemail_settings'
          'music.wav'
        ].join '/'

      if typeof @session.number.custom_music is 'string'
        @session.music ?= [
          @cfg.userdb_base_uri
          @session.number.user_database
          'voicemail_settings'
          @session.number.custom_music
        ].join '/'

      @session.music ?= @cfg.music
      @session.music ?= default_music

Set parameters

      yield @set

These are injected so that they may eventually show up in CDRs.

          ccnq_direction: @session.direction
          ccnq_account: @session.ccnq_account
          ccnq_profile: @session.profile
          ccnq_from_e164: @session.ccnq_from_e164
          ccnq_to_e164: @session.ccnq_to_e164

SIP parameters

          progress_timeout: 18
          call_timeout: 300
          effective_caller_id_number: @session.ccnq_from_e164
          sip_contact_user: @session.ccnq_from_e164
          sip_cid_type: 'pid'

      yield @export
        t38_passthru:true
        sip_wait_for_aleg_ack: @session.wait_for_aleg_ack ? true

Music

        hold_music: @session.music

      if @session.asserted?
        yield @set effective_caller_id_number: @session.asserted

      debug 'OK'
