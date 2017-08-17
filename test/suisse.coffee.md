    describe 'Switzerland', ->
      it 'should route', ->
        m = require '../middleware/client/egress/national-CH'

        ctx =
          session:
            direction:'egress'
            dialplan:'national'
            country:'ch'
          source: '0123456789'
          destination: '0987654321'
          debug: ->

        m.include.apply ctx
        assert.deepEqual ctx.session.ccnq_from_e164, '41123456789'
        assert.deepEqual ctx.session.ccnq_to_e164, '41987654321'

    assert = require 'assert'
