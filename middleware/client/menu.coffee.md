    @name = "huge-play:middleware:client:menu"
    run = require 'flat-ornament'

    @description = '''
      Handles routing to a given menu.
    '''

    @include = ->

      return unless @session?.direction is 'menu'

      unless @session.menu?
        @debug 'Missing menu data.'
        return

      @report state:'menu'

      await @action 'answer'
      call_is_answered = true

      await @export
        t38_passthru: false
        sip_wait_for_aleg_ack: not call_is_answered
      await @set
        sip_wait_for_aleg_ack: not call_is_answered

      @session.wait_for_aleg_ack = not call_is_answered

      @debug 'Menu starting.'
      @menu_depth = 0
      await run.call this, @session.menu, @ornaments_commands
        .catch (error) => @debug.catch error
      @debug 'Menu completed.'
      return
