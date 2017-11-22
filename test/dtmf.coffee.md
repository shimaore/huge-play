    seem = require 'seem'
    chai = require 'chai'
    chai.should()
    debug = (require 'tangible') 'huge-play:test:dtmf'

    sleep = (timeout) ->
      new Promise (resolve) ->
        setTimeout resolve, timeout

    describe 'DTMF', ->
      m = require '../middleware/dtmf'
      submit = null
      ctx =
        call:
          event_json: ->
          on: (event,cb) ->
            if event is 'DTMF'
              submit = (c) ->
                cb body: 'DTMF-Digit': c
        debug: ->
      m.include.call ctx

      it 'should receive a single digit', seem ->
        @timeout 1000
        ctx.dtmf.clear()
        p = ctx.dtmf.expect 1, 1
        yield sleep 400
        submit 'A'
        yield sleep 100
        v = yield p
        v.should.eql 'A'

      it 'should buffer a single digit', seem ->
        @timeout 1000
        ctx.dtmf.clear()
        yield sleep 500
        submit 'A'
        p = ctx.dtmf.expect 1, 1
        v = yield p
        v.should.eql 'A'

      it 'should timeout', seem ->
        @timeout 3000
        ctx.dtmf.clear()
        yield sleep 500
        p = ctx.dtmf.expect 1, 1, 500
        v = yield p
        v.should.eql ''

      it 'should report multiple digits', seem ->
        ctx.dtmf.clear()
        submit 'A'
        submit 'B'
        submit 'C'
        submit 'D'
        p = ctx.dtmf.expect 1, 10, 500
        v = yield p
        v.should.eql 'ABCD'

      it 'should report minimum number of digits', seem ->
        @timeout 3000
        ctx.dtmf.clear()
        submit 'A'
        p = ctx.dtmf.expect 2, 5, 250
        yield sleep 100
        submit 'B'

The last one will arrive too late, so it is not counted.

        yield sleep 300
        submit 'C'
        debug 'boo'
        v = yield p
        debug v
        v.should.eql 'AB'

      it 'should report fast digits', seem ->
        @timeout 3000
        ctx.dtmf.clear()
        yield sleep 50
        submit 'A'
        yield sleep 50
        p = ctx.dtmf.expect 2, 5, 250
        yield sleep 50
        submit 'B'

The last one arrives before timeout.

        yield sleep 50
        submit 'C'
        yield sleep 50
        v = yield p
        v.should.eql 'ABC'

      it 'should handle # beforehand', seem ->
        @timeout 3000
        ctx.dtmf.clear()
        yield sleep 50
        submit 'A'
        yield sleep 50
        submit 'B'
        yield sleep 50
        submit '#'
        p = ctx.dtmf.expect 1, 4, 250
        yield sleep 50
        submit 'C'
        v = yield p
        v.should.eql 'AB'

      it 'should handle # beforehand and skip afterwards', seem ->
        ctx.dtmf.clear()
        yield sleep 50
        submit 'A'
        yield sleep 50
        submit 'B'
        yield sleep 50
        submit '#'
        yield sleep 10
        p = ctx.dtmf.expect 1, 4, 250
        v = yield p
        yield sleep 50
        submit 'C'
        v.should.eql 'AB'

      it 'should handle # afterwards', seem ->
        ctx.dtmf.clear()
        p = ctx.dtmf.expect 1, 4, 250, 1000
        yield sleep 50
        submit 'A'
        yield sleep 50
        submit 'B'
        yield sleep 50
        submit '#'
        yield sleep 50
        submit 'C'
        v = yield p
        v.should.eql 'AB'

      it 'should respect maximum length (before)', seem ->
        ctx.dtmf.clear()
        submit 'A'
        submit 'B'
        submit 'C'
        submit 'D'
        submit 'E'
        p = ctx.dtmf.expect 4, 4, 250
        v = yield p
        v.should.eql 'ABCD'

      it 'should respect maximum length (after)', seem ->
        ctx.dtmf.clear()
        submit 'A'
        submit 'B'
        p = ctx.dtmf.expect 4, 4, 250
        submit 'C'
        submit 'D'
        submit 'E'
        v = yield p
        v.should.eql 'ABCD'
