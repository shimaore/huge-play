    Solid = require 'solid-gun'

    reference_id = ->
      Solid.time() + Solid.uniqueness()

Just like RedisClient, this needs a `redis` value, which should be an instance of RedisInterface (`normal-key/interface`).

    SET = (name) ->
      (value) -> @set name, value
    GET = (name) ->
      -> @get name

    class Reference
      constructor: (id) ->
        id ?= reference_id()
        @id = id

      _key: (name) -> "xref-#{@id}.#{name}"

      set: (name,value) ->
        key = @_key name
        @interface.setup_text key, @timeout
        @interface.update_text key, value
        return

      get: (name) ->
        key = @_key name
        [coherent,value] = @interface.get_text key
        value

      set_endpoint: SET 'endpoint'
      set_destination: SET 'destination'
      set_source: SET 'source'
      set_domain: SET 'domain'
      set_dev_logger: SET 'dev_logger'
      set_account: SET 'account'
      set_call_options: SET 'call_options'
      set_block_dtmf: SET 'block_dtmf'
      set_number: SET 'number'
      set_number_domain: SET 'number_domain'

      get_endpoint: GET 'endpoint'
      get_destination: GET 'destination'
      get_source: GET 'source'
      get_domain: GET 'domain'
      get_dev_logger: GET 'dev_logger'
      get_account: GET 'account'
      get_call_options: GET 'call_options'
      get_block_dtmf: GET 'block_dtmf'
      get_number: GET 'number'
      get_number_domain: GET 'number_domain'

    module.exports = Reference
