    seem = require 'seem'
    @name = 'carrier-egress'
    @include = seem ->
      m = @data.switch_r_sdp?.match /(.*m=audio \d+ RTP\/AVP)[\d ]*(.*)/
      if m?
        yield @export
          'nolocal:codec_string': 'PCMA@8000h@20i,GSM@8000h@20i'
        @set
          absolute_codec_string: 'PCMA@8000h@20i,GSM@8000h@20i'
          inherit_codec:false
          switch_r_sdp: "#{m[1]} 8 101#{m[2]}"
