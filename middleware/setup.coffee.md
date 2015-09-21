    seem = require 'seem'
    nimble = require 'nimble-direction'
    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:setup"
    assert = require 'assert'

    @config = seem ->
      yield nimble @cfg
      assert cfg.prov?, 'Nimble did not inject cfg.prov'

    @server_pre = ->
      yield nimble @cfg
      assert cfg.prov?, 'Nimble did not inject cfg.prov'

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

        unset: seem (name) ->
          return unless name?
          if typeof name is 'string'
              ctx.action 'unset', name
          else
            yield ctx.unset k for k in name

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
