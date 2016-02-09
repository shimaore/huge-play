    describe 'Modules', ->
      it 'should load', ->
        for m in [
          'middleware/setup.coffee.md'
          'middleware/setup-fifo.coffee.md'
          'middleware/cdr.coffee.md'

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
          'middleware/client/egress/france-3651.coffee.md'
          'middleware/client/ingress/fifo.coffee.md'
          'middleware/client/ingress/post.coffee.md'
          'middleware/client/ingress/privacy.coffee.md'
          'middleware/client/ingress/centrex-FR.coffee.md'
          'middleware/client/ingress/centrex-CH.coffee.md'
          'middleware/client/ingress/national-FR.coffee.md'
          'middleware/client/ingress/national-CH.coffee.md'
          'middleware/client/ingress/local-number.coffee.md'
          'middleware/client/ingress/post-send.coffee.md'
          'middleware/client/ingress/pre.coffee.md'
          'middleware/client/ingress/send.coffee.md'
          'middleware/client/forward/basic.coffee.md'
          'middleware/client/forward/basic-post.coffee.md'

          'middleware/carrier/setup.coffee.md'
          'middleware/carrier/egress/pre.coffee.md'
          'middleware/carrier/egress/send.coffee.md'
          'middleware/carrier/egress/send-tough-rate.coffee.md'
          'middleware/carrier/ingress/post.coffee.md'
          'middleware/carrier/ingress/send.coffee.md'
        ]
          require "../#{m}"
          ctx =
            cfg:
              sip_profiles:{}
            session:{}
            call:
              once: -> Promise.resolve null
              linger: -> Promise.resolve null
            req:
              variable: -> null
            data: {}
          (require "../#{m}").include.call ctx, ctx
