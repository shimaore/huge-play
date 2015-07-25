    describe 'France', ->
      it 'should route', ->
        m = require '../middleware/client/egress/france'

        ctx =
          session:
            direction:'egress'
            dialplan:'national'
            country:'fr'
          source: '0123456789'
          destination: '0987654321'

        m.include.apply ctx
        assert.deepEqual ctx.session.ccnq_from_e164, '33123456789'
        assert.deepEqual ctx.session.ccnq_to_e164, '33987654321'

    assert = require 'assert'
