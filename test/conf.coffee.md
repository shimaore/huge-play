    chai = require 'chai'
    chai.should()
    fs = require 'fs'

    it 'The FreeSwitch configuration should accept phrases', ->
      options = require './example.json'
      opts = {}
      for own k,v of options
        opts[k] = v
      opts.phrases = [
        require 'bumpy-lawyer/fr'
      ]
      config = (require '../conf/freeswitch') opts
      config.should.match /<action function="play-file" data="voicemail\/vm-to_record_greeting.wav"\/>/

    it 'The FreeSwitch configuration should accept cdr.url', ->
      options = require './cdr.json'
      config = (require '../conf/freeswitch') options
      config.should.match /<load module="mod_json_cdr"\/>/
      config.should.match /<param name="log-b-leg" value="false"\/>/
      config.should.match /<param name="url" value="http:\/\/127.0.0.1:5984\/cdr"\/>/

    it 'The FreeSwitch configuration', ->
      options = require './example.json'
      config = (require '../conf/freeswitch') options

      expected_config = (fs.readFileSync 'test/expected_config.xml', 'utf8').replace /\n */g, '\n'
      fs.writeFileSync '/tmp/config', config, 'utf-8'

      config.should.equal expected_config
