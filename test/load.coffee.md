    seem = require 'seem'
    describe 'Modules', ->
      list = [
          'middleware/logger.coffee.md'
          'middleware/setup.coffee.md'
          'middleware/setup-fifo.coffee.md'
          'middleware/cdr.coffee.md'
          'middleware/handled.coffee.md'
          'middleware/reference_in_pouchdb.coffee.md'
          'middleware/trace_in_pouchdb.coffee.md'

          'middleware/client/setup.coffee.md'
          'middleware/client/fifo.coffee.md'
          'middleware/client/egress/fifo.coffee.md'
          'middleware/client/egress/post.coffee.md'
          'middleware/client/egress/centrex-FR.coffee.md'
          'middleware/client/egress/centrex-CH.coffee.md'
          'middleware/client/egress/national-FR.coffee.md'
          'middleware/client/egress/national-CH.coffee.md'
          'middleware/client/egress/post-send.coffee.md'
          'middleware/client/egress/pre.coffee.md'
          'middleware/client/egress/privacy-FR.coffee.md'
          'middleware/client/egress/privacy-CH.coffee.md'
          'middleware/client/ingress/fifo.coffee.md'
          'middleware/client/ingress/post.coffee.md'
          'middleware/client/ingress/privacy.coffee.md'
          'middleware/client/ingress/centrex-FR.coffee.md'
          'middleware/client/ingress/centrex-CH.coffee.md'
          'middleware/client/ingress/national-FR.coffee.md'
          'middleware/client/ingress/national-CH.coffee.md'
          'middleware/client/ingress/local-number.coffee.md'
          'middleware/client/ingress/post-forward.coffee.md'
          'middleware/client/ingress/post-send.coffee.md'
          'middleware/client/ingress/pre.coffee.md'
          'middleware/client/ingress/flat-ornament.coffee.md'
          'middleware/client/ingress/send.coffee.md'
          'middleware/client/forward/basic.coffee.md'
          'middleware/client/forward/basic-post.coffee.md'

          'middleware/carrier/setup.coffee.md'
          'middleware/carrier/egress/pre.coffee.md'
          'middleware/carrier/egress/send.coffee.md'
          'middleware/carrier/ingress/post.coffee.md'
          'middleware/carrier/ingress/send.coffee.md'
        ]

      unit = (m) ->
        it "should load #{m}", seem ->
          ctx =
            cfg:
              sip_profiles:{}
              prefix_admin: ''
            session:{}
            call:
              once: -> Promise.resolve null
              linger: -> Promise.resolve null
            req:
              variable: -> null
              header: -> null
            data:
              'Channel-Context': 'sbc-ingress'
            get_ref: -> @session.reference_data = {}
            save_ref: ->
            set: ->
            export: ->
            debug: do ->
              debug = ->
              debug.csr = ->
              debug.dev = ->
              debug.ops = ->
              debug
          M = require "../#{m}"
          yield M.server_pre?.call ctx, ctx
          yield M.include.call ctx, ctx

      for m in list
        unit m
