    describe 'Modules', ->
      it 'should load', ->
        for m in [
          'middleware/setup.coffee.md'
          'middleware/cdr.coffee.md'
          'middleware/client/setup.coffee.md'
          'middleware/client/media.coffee.md'
          'middleware/client/egress/post.coffee.md'
          'middleware/client/egress/france.coffee.md'
          'middleware/client/egress/pre.coffee.md'
          'middleware/client/egress/france-3651.coffee.md'
          'middleware/client/ingress/post.coffee.md'
          'middleware/client/ingress/privacy.coffee.md'
          'middleware/client/ingress/france.coffee.md'
          'middleware/client/ingress/pre.coffee.md'
          'middleware/carrier/setup.coffee.md'
        ]
          require "../#{m}"
