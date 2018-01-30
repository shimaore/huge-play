    @name = "huge-play:middleware:client:menu"
    seem = require 'seem'
    run = require 'flat-ornament'

    @description = '''
      Handles routing to a given menu.
    '''

    @include = seem ->

      return unless @session?.direction is 'menu'

      unless @session.menu?
        @debug 'Missing menu data.'
        return

      @report state:'menu'

      yield @action 'answer'
      call_is_answered = true

      yield @export
        t38_passthru: false
        sip_wait_for_aleg_ack: not call_is_answered
      yield @set
        sip_wait_for_aleg_ack: not call_is_answered

      @session.wait_for_aleg_ack = not call_is_answered

      @debug 'Menu starting.'
      @menu_depth = 0
      yield run.call this, @session.menu, @ornaments_commands
        .catch (error) => @debug.catch error
      @debug 'Menu completed.'
      return
