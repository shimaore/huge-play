    @name = "huge-play:middleware:client:menu"
    seem = require 'seem'
    run = require 'flat-ornament'

    @description = '''
      Handles routing to a given menu.
    '''

    @include = seem ->

      return unless @session.direction is 'menu'

      unless @session.menu?
        @debug 'Missing menu data.'
        return

      yield @action 'answer'
      @debug 'Menu starting.'
      yield run.call this, @session.menu, @ornaments_commands
      @debug 'Menu completed.'
      return
