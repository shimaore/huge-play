    Solid = require 'solid-gun'
    seconds = 1000

    reference_id = ->
      Solid.time() + Solid.uniqueness()

    SET = (name) ->
      (value) -> @set name, value
    GET = (name) ->
      -> @get name

    SET_JSON = (name) ->
      (value) -> @set name, JSON.stringify value
    GET_JSON = (name) ->
      -> try JSON.parse await @get name

    class Reference

This needs to be extended with ::timeout and ::interface (a blue-rings or redis instance).

      _key: (name) -> "xref-#{@id}.#{name}"

      constructor: (id) ->
        id ?= reference_id()
        @id = id

      set_endpoint: SET 'endpoint'
      set_destination: SET 'destination'
      set_source: SET 'source'
      set_domain: SET 'domain'
      set_dev_logger: SET 'dev_logger'
      set_account: SET 'account'
      set_call_options: SET_JSON 'call_options'
      set_block_dtmf: SET 'block_dtmf'
      set_number: SET 'number'
      set_number_domain: SET 'number_domain'

      get_endpoint: GET 'endpoint'
      get_destination: GET 'destination'
      get_source: GET 'source'
      get_domain: GET 'domain'
      get_dev_logger: GET 'dev_logger'
      get_account: GET 'account'
      get_call_options: GET_JSON 'call_options'
      get_block_dtmf: GET 'block_dtmf'
      get_number: GET 'number'
      get_number_domain: GET 'number_domain'

Reference, using a RedisInterface (from `normaly-key/interface`) as its `interface`.

    class RedisInterfaceReference extends Reference

      set: (name,value) ->
        key = @_key name
        @interface.set key, name, value

      get: (name) ->
        key = @_key name
        @interface.get key, name

      clear_: (cat) ->
        key = @_key cat
        @interface.clear key

      add_: (cat,value) ->
        key = @_key cat
        @interface.add key, value

      del_: (cat,value) ->
        key = @_key cat
        @interface.remove key,value

      has_: (cat,value) ->
        key = @_key cat
        @interface.has key,value

      all_: (cat) ->
        key = @_key cat
        @interface.members key

Reference, using a BlueRing instance (from `blue-rings`) as its `interface`.

    class BlueRingReference extends Reference

      _expiry: -> Date.now() + @timeout*seconds

      set: (name,value) ->
        key = @_key name
        @interface.setup_text key, @_expiry()
        @interface.update_text key, value
        return

      get: (name) ->
        key = @_key name
        [coherent,value] = @interface.get_text key
        value

Clearable sets
--------------

Currently we use three such sets: 'skill', 'queue', and 'user-tag'.

These are implemented using the existing PN-Set CRDT, by creating a new set every time we clear.
The list of PN-Set is indexed by a counter.

      _set_key: (cat) ->
        index_key = @_key cat
        @interface.setup_counter index_key, @_expiry()
        [coherent,index] = @interface.get_counter index_key
        index ?= 0
        @_key [cat,index].join '/'

      clear_: (cat) ->
        index_key = @_key cat
        @interface.setup_counter index_key, @_expiry()
        @interface.increment index_key, 1
        return

      add_: (cat,value) ->
        key = @_set_key cat
        @interface.setup_set key, @_expiry()
        @interface.add key, value
        return
      del_: (cat,value) ->
        key = @_set_key cat
        @interface.setup_set key, @_expiry()
        @interface.remove key, value
        return
      has_: (cat,value) ->
        key = @_set_key cat
        [coherent,value] = @interface.has key, value
        value
      all_: (cat) ->
        key = @_set_key cat
        [coherent,value] = @interface.value key
        value ? []

    module.exports = {Reference,RedisInterfaceReference,BlueRingReference}
