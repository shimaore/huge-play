    seem = require 'seem'
    @name = 'huge-play:middleware:handled'

    clean_uri = (t) ->
      t
      .replace /^<(.+)>$/, '$1'
      .replace /^sip:(.+)$/, '$1'
      .replace /^([^@]+)@([^?]+)/, '$1@$2'

    (require 'assert') '107@example.net',
      clean_uri '<sip:107@example.net?Replaces=0_2282464607%40192.168.1.19%3Bto-tag%3DNer4j80v3g6Ug%3Bfrom-tag%3D4287953264>'

    @include = seem ->
      return unless @session?.direction is 'handled'
      refer_to = clean_uri @req.variable 'sip_refer_to'
      d = "sofia/#{@session.sip_profile}/#{refer_to}"

      @debug 'transfering call to', d
      @report
        state:'handled'
        handled_to: d
      res = yield @action 'bridge', d
      @debug 'call transferred', res
