    @name = 'huge-play:middleware:client:ornaments'
    commands = require './commands'

    @include = ->

Inject the commands defined in `./commands.coffee.md`
-----------------------------------------------------

      @ornaments_commands ?= {}

      Object.assign @ornaments_commands, commands

      return
