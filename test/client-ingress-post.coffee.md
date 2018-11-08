    chai = require 'chai'
    chai.use require 'chai-as-promised'
    chai.should()

    describe 'client-ingress-post', ->
      m = require '../middleware/client/ingress/post'
      s = require '../middleware/setup'
      sc = require '../middleware/client/setup'

      class Foo
        get_destination: ->
        add_in: ->
        set_endpoint: ->
        set_account: ->
        get_call_options: ->
        get_dev_logger: ->
        get_in: -> Promise.resolve []
      cfg =
        prov:
          get: (id) ->
            return Promise.resolve docs[id]
        Reference: Foo

      docs =
        'number:1234@some':
          _id: 'number:1234@some'
          cfb_number:'365'
          cfa_number:'488'
          cfa_enabled:false
          cfnr_number:'981'
          cfnr_enabled:false
          cfda: 'sip:387@example.net'

      it 'should use cfb_number', (done) ->
        ctx =
          cfg: cfg
          destination: '1234'
          session:
            direction: 'ingress'
            number_domain: 'some'
          action: -> Promise.resolve null
          res:
            set: -> Promise.resolve null
            export: -> Promise.resolve null
          req:
            variable: ->
          call:
            uuid: 'little-bear'
            emit: ->
            on: ->
          data: # useful-wind/router
            'Channel-Context': 'sbc-ingress'
        s.include.call ctx, ctx
        sc.include.call ctx, ctx
        m.include
          .call ctx
          .then ->
            ctx.session.should.have.property 'cfb_number', '365'
            ctx.session.should.not.have.property 'cfa_number'
            ctx.session.should.not.have.property 'cfnr_number'
            ctx.session.should.have.property 'cfda', 'sip:387@example.net'
            done()
          .catch done
        null
