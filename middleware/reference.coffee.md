    seem = require 'seem'
    Solid = require 'solid-gun'
    RedisClient = require 'normal-key/client'

    reference_id = ->
      Solid.time() + Solid.uniqueness()

Just like RedisClient, this needs a `redis` value, which should be an instance of RedisInterface (`normal-key/interface`).

    SET = (name) ->
      (value) -> @set name, value
    GET = (name) ->
      -> @get name

    class Reference extends RedisClient
      constructor: (@id = reference_id()) ->
        super 'xref', @id
        @__in_key = "#{@class_name}-#{@key}-i"

      set_endpoint: SET 'endpoint'
      set_destination: SET 'destination'
      set_source: SET 'source'
      set_domain: SET 'domain'
      set_dev_logger: SET 'dev_logger'
      set_account: SET 'account'
      set_call_options: (options) ->
        @set 'call_options', JSON.stringify options
      set_block_dtmf: SET 'block_dtmf'

      get_endpoint: GET 'endpoint'
      get_destination: GET 'destination'
      get_source: GET 'source'
      get_domain: GET 'domain'
      get_dev_logger: GET 'dev_logger'
      get_account: GET 'account'
      get_call_options: seem ->
        options = yield @get 'call_options'
        if options?
          JSON.parse options
        else
          {}
      get_block_dtmf: GET 'block_dtmf'

      add_in: (role) ->
        @redis.add @__in_key, role

      get_in: ->
        @redis.members @__in_key

    module.exports = Reference
