    seem = require 'seem'
    pkg = require '../../package.json'
    @name = "#{pkg.name}/middleware/media"

Sources:
https://wiki.freeswitch.org/wiki/Codec_Negotiation
https://wiki.freeswitch.org/wiki/Codecs
https://wiki.freeswitch.org/wiki/Proxy_Media
https://freeswitch.org/confluence/display/FREESWITCH/Bypass+Media+Overview
https://wiki.freeswitch.org/wiki/Channel_Variables#Codec_Related

    @include = seem ->

      ###

bypass_media = Flow Around (but can still retrieve media)

      yield @set bypass_media: if @session.bypass_media then true else false

Probably should set  sip_enable_soa to false if doing bypass

      yield @set sip_enable_soa: if @session.bypass_media then false else true

bypass_media_after_bridge: process media until answered, same as bypass_media after call is answered,
rtp_autoflush
rtp_autoflush_during_bridge


proxy_media = Pass Through / Transparent Codec (not needed for T.38 anymore; use e.g. for modem? ZRTP)
Make sure to answer() the call if need to play media on a proxy-media call.

      yield @action 'set', "proxy_media=#{if @session.proxy_media then true else false}"

ep_codec_string: when using late-neg, list of codecs proposed by the A-leg.

codec_string: overrides outbound-codec-prefs
[`sip_renegotiate_codec_on_reinvite`](https://wiki.freeswitch.org/wiki/Variable_sip_renegotiate_codec_on_reinvite)
[`suppress-cng`](https://wiki.freeswitch.org/wiki/Variable_suppress-cng)

      ###

      m = @data.switch_r_sdp?.match /(.*m=audio \d+ RTP\/AVP)[\d ]*(.*)/
      if m?
        yield @export
          'nolocal:codec_string': 'PCMA@8000h@20i,GSM@8000h@20i'
        yield @set

absolute_codec_string: forces a codec on the B-leg; compare to disable-transcoding=true (which forces the A-leg codec on the B-leg)

          absolute_codec_string: 'PCMA@8000h@20i,GSM@8000h@20i'

inherit_codec: when using late-neg, passes the B-len answer to the A-leg

          inherit_codec:false

          switch_r_sdp: "#{m[1]} 8 101#{m[2]}"

No Device Left Behind

          verbose_sdp: true
