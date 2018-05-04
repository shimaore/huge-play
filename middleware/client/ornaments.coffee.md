    @name = 'huge-play:middleware:client:ornaments'
    commands = require './commands'

    @include = ->

Inject the commands defined in `./commands.coffee.md`
-----------------------------------------------------

      @ornaments_commands ?= {}

      for own k,v of commands
        @ornaments_commands[k] = v

      return
