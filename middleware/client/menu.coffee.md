    @name = "huge-play:middleware:client:menu"
    debug = (require 'tangible') @name
    compile = require 'flat-ornament/compile'

    @description = '''
      Handles routing to a given menu.
    '''

    @include = ->

      return unless @session?.direction is 'menu'

      unless @session.menu?
        debug 'Missing menu data.'
        return

      @report state:'menu'

      await @action 'answer'
      @session.sip_wait_for_aleg_ack = false

      await @export
        t38_passthru: false
        sip_wait_for_aleg_ack: @session.sip_wait_for_aleg_ack
      await @set
        sip_wait_for_aleg_ack: @session.sip_wait_for_aleg_ack

      debug 'Menu starting.'
      @menu_depth = 0
      fun = compile @session.menu, @ornaments_commands
      if fun?
        await fun.call this
          .catch (error) => debug.dev 'Menu', error
      else
        debug.dev 'Compilation failed', @session.menu
      debug 'Menu completed.'
      return
