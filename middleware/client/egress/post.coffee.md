    url = require 'url'

    pkg = require '../../../package.json'
    @name = "#{pkg.name}:middleware:client:egress:post"
    debug = (require 'tangible') @name
    assert = require 'assert'
    tones = require '../tones'

    default_music = tones.loop tones.fr.waiting

    @include = ->
      return unless @session?.direction is 'egress'

      @debug 'Ready'

      unless @session.ccnq_from_e164? and @session.ccnq_to_e164?
        @debug 'Missing e164 numbers'
        return @respond '484'

* session.e164_number (object) The doc.global_number record for the source of an outbound call.

      @session.e164_number = await @cfg.prov.get("number:#{@session.ccnq_from_e164}").catch -> {}
      await @reference.set_number @session.ccnq_from_e164
      await @user_tags @session.e164_number.tags

* session.e164_number.fs_variables See doc.global_number.fs_variables
* doc.global_number (object, optional) Additional FreeSwitch variables to be set on egress calls (for the calling number). These will show up in CDRs on the client side.

      if @session.e164_number.fs_variables?
        await @set @session.e164_number.fs_variables

The URL module parses the SIP username as `auth`.

* hdr.P-Charge-Info Required for egress calls on the client side. A `403 No Charge-Info` SIP error is generated if it is not present. The username part is used to populate session.ccnq_account.

      pci = @req.header 'P-Charge-Info'

      if pci?
        @session.ccnq_account = (url.parse pci).auth
      else
        @session.ccnq_account = await @reference.get_account()

      @session.ccnq_account ?= null

      unless @session.ccnq_account?
        @debug 'Invalid Charge-Info', pci
        return @respond '403 Missing Charge-Info'

      await @reference.set_account @session.ccnq_account

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

      if @session.country? and @session.country of tones
        @session.music ?= tones.loop tones[@session.country].waiting

      @session.music ?= @cfg.music
      @session.music ?= default_music

Set parameters

      @session.cdr_direction = @session.direction

      await @set

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

Codec negotiation with late-neg:

          inherit_codec: @session.inherit_codec ? true

      if @session.ringback?
        await @set ringback: @session.ringback

      await @export
        t38_passthru:true
        sip_wait_for_aleg_ack: @session.wait_for_aleg_ack ? true

Music

        hold_music: @session.music

      if @session.asserted?
        await @set effective_caller_id_number: @session.asserted

      if @session.dev_logger
        await @reference.set_dev_logger true

      @report
        state: 'client-egress-accepted'
        account: @session.ccnq_account
        number: @session.e164_number._id
        from_e164: @session.ccnq_from_e164
        to_e164: @session.ccnq_to_e164

      @debug 'OK'
