{renderable} = L = require 'acoustic-line'
{hostname} = require 'os'

module.exports = renderable (cfg) ->
  {doctype,document,section,configuration,settings,params,param,modules,module,load,network_lists,list,node,global_settings,profiles,profile,mappings,map,context,extension,condition,action,macros,fifos} = L
  name = cfg.name ? 'server'
  the_profiles = cfg.profiles ?
    sbc:
      sip_port: 5080
      socket_port: 5721 # Outbound-Socket port
  modules_to_load = [
    'mod_logfile'
    'mod_event_socket'
    'mod_commands'
    'mod_dptools'
    'mod_loopback'
    'mod_dialplan_xml'
    'mod_sofia'
    'mod_sndfile'
    'mod_tone_stream'
    'mod_httapi'
    'mod_fifo'
  ]
  if cfg.cdr?.url?
    modules_to_load.push 'mod_json_cdr'
  if cfg.modules?
    modules_to_load = modules_to_load.concat cfg.modules

  phrases_to_load = [
    # require 'bumpy-lawyer/en'
    require 'bumpy-lawyer/fr'
  ]
  if cfg.phrases?
    phrases_to_load = phrases_to_load.concat cfg.phrases

  doctype()
  document type:'freeswitch/xml', ->
    section name:'configuration', ->
      configuration name:'switch.conf', ->
        settings ->
          param name:'switchname', value:"freeswitch-#{name}@#{cfg.host ? hostname()}"
          param name:'core-db-name', value:"/dev/shm/freeswitch/core-#{name}.db"
          param name:'rtp-start-port', value:49152
          param name:'rtp-end-port', value:65534
          param name:'max-sessions', value:2000
          param name:'sessions-per-second', value:2000
          param name:'min-idle-cpu', value:1
          param name:'loglevel', value:'err'
      configuration name:'modules.conf', ->
        modules ->
          for module in modules_to_load
            load {module}
      configuration name:'logfile.conf', ->
        settings ->
          param name:'rotate-on-hup', value:true
        profiles ->
          profile name:'default', ->
            settings ->
              param name:'logfile', value:"log/freeswitch.log"
              param name:'rollover', value:10*1000*1000
              param name:'uuid', value:true
            mappings ->
              map name:'important', value:'err,crit,alert'
      configuration name:'event_socket.conf', ->
        settings ->
          param name:'nat-map', value:false
          param name:'listen-ip', value:'127.0.0.1'
          # Inbound-Socket port
          socket_port = cfg.socket_port ? 5722
          param name:'listen-port', value: socket_port
          param name:'password', value:'ClueCon'
      configuration name:"acl.conf", ->
        network_lists ->
          for name, cidrs of cfg.acls
            list name:name, default:'deny', ->
              for cidr in cidrs
                node type:'allow', cidr:cidr
      configuration 'fifo.conf', ->

      if cfg.cdr?.url?
        configuration name:'json_cdr.conf', ->
          settings ->
            param
              name:'auth-scheme'
              value: cfg.cdr.auth_scheme ? 'basic'
            param
              name:'encode-values'
              value: cfg.cdr.encode_values ? false
            param
              name:'log-dir'
              value: cfg.cdr.log_dir ? 'cdr'
            param
              name:'log-b-leg'
              value: cfg.cdr.log_b_leg ? false
            param
              name:'cred'
              value: cfg.cdr.cred ? ''
            param
              name:'url'
              value: cfg.cdr.url

      configuration name:'sofia.conf', ->
        global_settings ->
          param name:'log-level', value:1
          param name:'debug-presence', value:0
        profiles ->
          profile_module = cfg.profile_module ? require './profile'
          for name, p of the_profiles
            # Timer values see http://tools.ietf.org/html/rfc3261#page-265
            p.timer_t1 ?= 250  # 500ms in RFC3261; works well in practice
            p.timer_t4 ?= 5000 # RFC3261 section 17.1.2.2
            p.timer_t2 ?= 4000 # RFC3261 section 17.1.2.2
            p.timer_t1x64 ?= 64*p.timer_t1
            # Note: p.local_ip is defaulted by huge-play:middleware:carrier:setup to p.ingress_sip_ip
            p.local_ip ?= 'auto'
            p.inbound_codec ?= 'PCMA'
            p.outbound_codec ?= 'PCMA'
            p.acl ?= 'default'

            q = {}
            q[k] = v for own k,v of p

            # Ingress profile (carrier-side) is at port `sip_port`.

            q.name = q.context = "#{name}-ingress"
            q.sip_port = p.ingress_sip_port ? p.sip_port
            q.acl = q.name if cfg.acl_per_profile
            profile_module.call L, q

            # Egress profile (client-side) is at port 'sip_port+10000'.

            q.name = q.context = "#{name}-egress"
            q.sip_port = p.egress_sip_port ? 10000 + q.sip_port
            q.acl = q.name if cfg.acl_per_profile
            profile_module.call L, q

      configuration name:'httapi.conf', ->
        settings ->
        profiles ->
          # In mod_httapi.c/fetch_cache_data(), the profile_name might be set as a parameter, a setting, or defaults to `default`.
          profile name:'default', ->
            params ->
              param 'gateway-url', cfg.httapi_url ? ''
              param 'gateway-credentials', cfg.httapi_credentials ? ''
              param 'auth-scheme', cfg.httapi_authscheme ? 'basic'
              param 'enable-cacert-check', cfg.httapi_cacert_check ? true
              param 'enable-ssl-verifyhost', cfg.httpapi_verify_host ? true
              param 'timeout', cfg.httapi_timeout ? 120

    section name:'dialplan', ->

      for name, p of the_profiles
        for direction in ['ingress', 'egress']
          context name:"#{name}-#{direction}", ->
            # Note: p.socket_port is defaulted by huge-play:middleware:carrier:setup to cfg.port ? 5702
            extension name:"socket", ->
              condition field:'destination_number', expression:'^.+$', ->
                action application:'multiset', data:"direction=#{direction} profile=#{name}"
                action application:'socket', data:"127.0.0.1:#{p.socket_port} async full"
            extension name:'refer', ->
              condition field:'${sip_refer_to}', expression:'^.+$', ->
                action application:'multiset', data:"direction=#{direction} profile=#{name}"
                action application:'socket', data:"127.0.0.1:#{p.socket_port} async full"

    sound_dir = cfg.sound_dir ? '/opt/freeswitch/share/freeswitch/sounds'
    section 'phrases', ->
      macros ->
        for module in phrases_to_load
          (module.include sound_dir) cfg
