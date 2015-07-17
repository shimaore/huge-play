    seem = require 'seem'
    @include = (ctx) ->

      ctx[k] = v for own k,v of {
        statistics: @cfg.statistics

        set: seem (name,value) ->
          return unless name?
          if typeof name is 'string'
            if value is null
              ctx.action 'unset', name
            else
              ctx.action 'set', "#{name}=#{value}"
          else
            yield ctx.set k,v for own k,v of name

        export: seem (name,value) ->
          return unless name?
          if typeof name is 'string'
            if value is null
              @action 'export', name
            else
              @action 'export', "#{name}=#{value}"
          else
            yield ctx.set k,v for own k,v of name

        respond: (response) ->
          @action 'respond', response
      }
