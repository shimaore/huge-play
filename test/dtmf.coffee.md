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
      m.include.call ctx

      it 'should receive a single digit', ->
        @timeout 1000
        ctx.dtmf.clear()
        p = ctx.dtmf.expect 1, 1
        await sleep 400
        submit 'A'
        await sleep 100
        v = await p
        v.should.eql 'A'

      it 'should buffer a single digit', ->
        @timeout 1000
        ctx.dtmf.clear()
        await sleep 500
        submit 'A'
        p = ctx.dtmf.expect 1, 1
        v = await p
        v.should.eql 'A'

      it 'should timeout', ->
        @timeout 3000
        ctx.dtmf.clear()
        await sleep 500
        p = ctx.dtmf.expect 1, 1, 500
        v = await p
        v.should.eql ''

      it 'should report multiple digits', ->
        ctx.dtmf.clear()
        submit 'A'
        submit 'B'
        submit 'C'
        submit 'D'
        p = ctx.dtmf.expect 1, 10, 500
        v = await p
        v.should.eql 'ABCD'

      it 'should report minimum number of digits', ->
        @timeout 3000
        ctx.dtmf.clear()
        submit 'A'
        p = ctx.dtmf.expect 2, 5, 250
        await sleep 100
        submit 'B'

The last one will arrive too late, so it is not counted.

        await sleep 300
        submit 'C'
        debug 'boo'
        v = await p
        debug v
        v.should.eql 'AB'

      it 'should report fast digits', ->
        @timeout 3000
        ctx.dtmf.clear()
        await sleep 50
        submit 'A'
        await sleep 50
        p = ctx.dtmf.expect 2, 5, 250
        await sleep 50
        submit 'B'

The last one arrives before timeout.

        await sleep 50
        submit 'C'
        await sleep 50
        v = await p
        v.should.eql 'ABC'

      it 'should handle # beforehand', ->
        @timeout 3000
        ctx.dtmf.clear()
        await sleep 50
        submit 'A'
        await sleep 50
        submit 'B'
        await sleep 50
        submit '#'
        p = ctx.dtmf.expect 1, 4, 250
        await sleep 50
        submit 'C'
        v = await p
        v.should.eql 'AB'

      it 'should handle # beforehand and skip afterwards', ->
        ctx.dtmf.clear()
        await sleep 50
        submit 'A'
        await sleep 50
        submit 'B'
        await sleep 50
        submit '#'
        await sleep 10
        p = ctx.dtmf.expect 1, 4, 250
        v = await p
        await sleep 50
        submit 'C'
        v.should.eql 'AB'

      it 'should handle # afterwards', ->
        ctx.dtmf.clear()
        p = ctx.dtmf.expect 1, 4, 250, 1000
        await sleep 50
        submit 'A'
        await sleep 50
        submit 'B'
        await sleep 50
        submit '#'
        await sleep 50
        submit 'C'
        v = await p
        v.should.eql 'AB'

      it 'should respect maximum length (before)', ->
        ctx.dtmf.clear()
        submit 'A'
        submit 'B'
        submit 'C'
        submit 'D'
        submit 'E'
        p = ctx.dtmf.expect 4, 4, 250
        v = await p
        v.should.eql 'ABCD'

      it 'should respect maximum length (after)', ->
        ctx.dtmf.clear()
        submit 'A'
        submit 'B'
        p = ctx.dtmf.expect 4, 4, 250
        submit 'C'
        submit 'D'
        submit 'E'
        v = await p
        v.should.eql 'ABCD'
