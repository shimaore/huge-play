    @name = 'huge-play:middleware:client:ornaments'
    seem = require 'seem'
    commands = require './commands'

    @include = ->

Inject the commands defined in `./commands.coffee.md`
-----------------------------------------------------

      @ornaments_commands ?= {}

      for own k,v of commands
        @ornaments_commands[k] = v

      return
