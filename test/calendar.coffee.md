    {debug} = (require 'tangible') 'test:calendar'
    (require 'chai').should()
    describe 'Commands', ->

      commands = require '../middleware/client/commands'

      {in_calendars} = commands

      it 'in calendars for a specific calendar', ->
        self =
          debug: debug
          session:
            number_domain_data:
              calendars: [
                {
                label: 'Open Days'
                dates: [
                  '2017-06-23'
                  '2017-06-24'
                  (new Date()).toISOString()[0...10]
                  '2018-10-24'
                  ]
                }
                {
                label: 'More Days'
                dates: [
                  '2017-06-23'
                  '2017-06-24'
                  ]
                }
              ]
        in_calendars.call(self, '0').should.be.true
        in_calendars.call(self,  0 ).should.be.true
        in_calendars.call(self, '1').should.be.false
