    seem = require 'seem'
    describe 'Normal modules', ->
      require '../middleware/client/commands'
    describe 'Modules', ->
      list = [
          'middleware/setup.coffee.md'
          'middleware/cdr.coffee.md'
          'middleware/handled.coffee.md'
          'middleware/dtmf.coffee.md'
          'middleware/prompt.coffee.md'
          'middleware/reference_in_pouchdb.coffee.md'
          'middleware/trace_in_pouchdb.coffee.md'
          'middleware/trace_in_tangible.coffee.md'

          'middleware/client/setup.coffee.md'
          'middleware/client/fifo.coffee.md'
          'middleware/client/ornaments.coffee.md'
          'middleware/client/menu.coffee.md'
          'middleware/client/queuer.coffee.md'
          'middleware/client/place-call.coffee.md'
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
        L = require 'tangible/middleware'
        S = require '../middleware/setup.coffee.md'
        it "should load #{m}", seem ->
          cfg =
            prefix_admin: ''
          ctx = {cfg}

          M = require "../#{m}"
          yield L.server_pre.call ctx, ctx
          yield S.server_pre.call ctx, ctx
          yield M.server_pre?.call ctx, ctx

          cfg.statistics =
            on: ->
            emit: ->
            add: ->
          socket =
            on: ->
            emit: ->
          ctx = {cfg,socket}
          yield L.notify.call ctx, ctx
          yield S.notify.call ctx, ctx
          yield M.notify?.call ctx, ctx

          call_ctx =
            cfg: ctx.cfg # useful-wind/router
            session:{} # useful-wind/router
            call: # useful-wind/router + esl
              once: -> Promise.resolve null
              on: ->
              emit: ->
              linger: -> Promise.resolve null
              exit: -> Promise.resolve null
            req: # useful-wind/router
              variable: -> null
              header: -> null
            res: # useful-wind/router
              set: -> Promise.resolve null
              export: -> Promise.resolve null
            data: # useful-wind/router
              'Channel-Context': 'sbc-ingress'
          call_ctx.cfg.statistics ?=  # thinkable-ducks/server
            emit: ->
            add: ->

          yield L.include.call call_ctx, call_ctx
          yield S.include.call call_ctx, call_ctx
          yield M.include.call call_ctx, call_ctx

      for m in list
        unit m
