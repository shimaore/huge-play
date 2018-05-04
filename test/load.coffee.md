    most = require 'most'
    describe 'Normal modules', ->
      require '../middleware/client/commands'
    describe 'Modules', ->
      list = [
          # 'middleware/setup'
          'middleware/cdr'
          'middleware/dtmf'
          'middleware/prompt'

          'middleware/client/setup'
          'middleware/client/ornaments'
          'middleware/client/queuer'
          'middleware/client/place-call'
          'middleware/handled'

          'middleware/client/menu'
          'middleware/client/conference'
          'middleware/client/fifo'

          'middleware/client/egress/pre'
          'middleware/client/egress/centrex-redirect'
          'middleware/client/egress/centrex-CH'
          'middleware/client/egress/centrex-FR'
          'middleware/client/egress/fifo'
          'middleware/client/egress/privacy-CH'
          'middleware/client/egress/privacy-FR'
          'middleware/client/egress/national-CH'
          'middleware/client/egress/national-FR'
          'middleware/client/egress/post'
          'middleware/client/egress/post-send'

          'middleware/client/ingress/pre'
          'middleware/client/ingress/privacy'
          'middleware/client/ingress/national-CH'
          'middleware/client/ingress/national-FR'
          'middleware/client/ingress/local-number'
          'middleware/client/ingress/centrex-redirect'
          'middleware/client/ingress/centrex-CH'
          'middleware/client/ingress/centrex-FR'
          'middleware/client/ingress/fifo'
          'middleware/client/ingress/post'
          'middleware/client/ingress/post-send'
          'middleware/client/ingress/flat-ornament'
          'middleware/client/ingress/send'

          'middleware/client/forward/basic'
          'middleware/client/ingress/post-forward'
          'middleware/client/forward/basic-post'

          'middleware/carrier/setup'
          'middleware/carrier/egress/pre'
          'middleware/carrier/egress/send'
          'middleware/carrier/ingress/post'
          'middleware/carrier/ingress/send'
        ]

      unit = (m) ->
        L = require 'tangible/middleware'
        S = require '../middleware/setup'
        it "should load #{m}", ->
          cfg =
            prefix_admin: 'http://127.0.0.1:3987'
            redis: {}
          ctx = {
            cfg
            most_shutdown: most.just yes
          }

          M = require "../#{m}"
          await L.server_pre.call ctx, ctx
          await S.server_pre.call ctx, ctx
          await M.server_pre?.call ctx, ctx

          cfg.statistics =
            on: ->
            emit: ->
            add: ->
          socket =
            on: ->
            emit: ->
          ctx = {cfg,socket}
          await L.notify.call ctx, ctx
          await S.notify.call ctx, ctx
          await M.notify?.call ctx, ctx

          call_ctx =
            cfg: ctx.cfg # useful-wind/router
            session:{} # useful-wind/router
            call: # useful-wind/router + esl
              once: -> Promise.resolve body: {}
              on: ->
              emit: ->
              linger: -> Promise.resolve null
              exit: -> Promise.resolve null
              event_json: -> Promise.resolve null
            req: # useful-wind/router
              variable: -> null
              header: -> null
            res: # useful-wind/router
              set: -> Promise.resolve null
              export: -> Promise.resolve null
            data: # useful-wind/router
              'Channel-Context': 'sbc-ingress'
            reference:
              get_block_dtmf: ->
              get_in: -> Promise.resolve []
              get_destination: -> Promise.resolve null
              get_call_options: -> Promise.resolve {}
          call_ctx.cfg.statistics ?=  # thinkable-ducks/server
            emit: ->
            add: ->

          C = require '../middleware/cdr'

          await L.include.call call_ctx, call_ctx
          await S.include.call call_ctx, call_ctx
          await C.include.call call_ctx, call_ctx
          await M.include.call call_ctx, call_ctx
          S.end.call call_ctx, call_ctx

          cfg.global_redis_client.end()

      for m in list
        unit m
