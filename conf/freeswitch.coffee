{renderable} = L = require 'acoustic-line'
{hostname} = require 'os'

module.exports = renderable (cfg) ->
  {doctype,document,section,configuration,settings,params,param,modules,module,load,network_lists,list,node,global_settings,profiles,profile,mappings,map,context,extension,condition,action,macros,fifos} = L

  # cfg.name (string) Internal name for the FreeSwitch instance
  name = cfg.name ? 'server'
  # cfg.profiles (object) Maps profile name to profile definition (containg cfg.profiles[].sip_port, cfg.profiles[].socket_port, etc.)
  # cfg.profiles.sbc (object) The default profile for the huge-play module, defaults to using `sip_port` 5080 and `socket_port` 5721.
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
    'mod_sofia'
    'mod_sndfile'
    'mod_tone_stream'
    'mod_httapi'
    'mod_fifo'
  ]
  # cfg.cdr.url (URL) where to push FreeSwitch CDRs
  if cfg.cdr?.url?
    modules_to_load.push 'mod_json_cdr'
  # cfg.modules (array) extraneous modules for FreeSwitch
  if cfg.modules?
    modules_to_load = modules_to_load.concat cfg.modules

  phrases_to_load = [
    require 'bumpy-lawyer/en'
    require 'bumpy-lawyer/fr'
  ]
  # cfg.phrases (array) extraneous language phrase (such as those provided by the bumpy-lawyer project) for FreeSwitch
  if cfg.phrases?
    phrases_to_load = phrases_to_load.concat cfg.phrases

  doctype()
  document type:'freeswitch/xml', ->
    section name:'configuration', ->
      configuration name:'switch.conf', ->
        settings ->
          # cfg.host (hostname) used preferentially to the automatically-determined hostname for FreeSwitch
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
          # cfg.socket_port (integer) Port for the event socket for FreeSwitch (defaults to 5722)
          socket_port = cfg.socket_port ? 5722
          param name:'listen-port', value: socket_port
          param name:'password', value:'ClueCon'
      configuration name:"acl.conf", ->
        network_lists ->
          # cfg.acls (object) Maps ACL names to cfg.acls[].cidrs arrays for FreeSwitch.
          for name, cidrs of cfg.acls
            list name:name, default:'deny', ->
              for cidr in cidrs
                node type:'allow', cidr:cidr
      configuration 'fifo.conf', ->
        settings ->
          param 'delete-all-outbound-member-on-startup', true

      if cfg.cdr?.url?
        configuration name:'json_cdr.conf', ->
          settings ->
            # cfg.cdr.auth_scheme (string) Authentication scheme for FreeSwitch CDR (default: "basic")
            # cfg.cdr.encode_values (boolean) Whether to encode values for FreeSwitch CDR (default: false)
            # cfg.cdr.log_dir (string) JSON FreeSwitch CDR logging directory (default: "cdr")
            # cfg.cdr.log_b_leg (boolean) Whether to log on the b-leg for FreeSwitch CDR (default: false)
            # cfg.cdr.cred (string) Credentails for FreeSwitch CDR (default: '')
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
          # cfg.profile_module (Node.js module) module to use to build Sofia profiles (default: huge-play's)
          profile_module = cfg.profile_module ? require './profile'
          for name, p of the_profiles
            # cfg.profiles[].timer_t1 (integer) SIP timer T1 for FreeSwitch (default: 250)
            # cfg.profiles[].timer_t1x64 (integer) SIP timer T1*64 for FreeSwitch (default: 64*timer_t1)
            # cfg.profiles[].timer_t2 (integer) SIP timer T2 for FreeSwitch (default: 4000)
            # cfg.profiles[].timer_t4 (integer) SIP timer T4 for FreeSwitch (default: 5000)
            # Timer values see http://tools.ietf.org/html/rfc3261#page-265
            p.timer_t1 ?= 250  # 500ms in RFC3261; works well in practice
            p.timer_t4 ?= 5000 # RFC3261 section 17.1.2.2
            p.timer_t2 ?= 4000 # RFC3261 section 17.1.2.2
            p.timer_t1x64 ?= 64*p.timer_t1
            # Note: p.local_ip is defaulted by huge-play:middleware:carrier:setup to p.ingress_sip_ip
            # cfg.profiles[].local_ip (string) local binding IP for SIP for FreeSwitch. Defaults to `auto`, except for huge-play's carrier configuration where it defaults to cfg.profiles[].ingress_sip_ip
            p.local_ip ?= 'auto'

            # cfg.profiles[].inbound_codec (string) inbound codec list (default: `PCMA`)
            # cfg.profiles[].outbound_codec (string) outbound codec list (default: `PCMA`)
            # cfg.profiles[].acl (string) SIP port ACL name (default: `default`) If cfg.profiles[].acl_per_profile is set, the name default to the profile's `<name>-ingress` or `<name>-egress` name, instead.
            p.inbound_codec ?= 'PCMA'
            p.outbound_codec ?= 'PCMA'
            p.acl ?= 'default'
            p.sip_trace ?= false

            q = {}
            q[k] = v for own k,v of p

            # cfg.profiles[] Each profile's name is used to build two names, `<name>-ingress` and `<name>-egress`. These names are used as the actual profile names (in huge-play) and the target dialplan context name (also as the ACL name, if `acl_per_profile` is set).
            # cfg.profiles[].sip_port (integer) The SIP port for the ingress profile defaults to the profile's cfg.profiles[].ingress_sip_port or the cfg.profiles[].sip_port value. The SIP port for the egress profile defaults to the profile's cfg.profiles[].egress_sip_port, or 10000 plus the ingress SIP port.
            # cfg.profiles[].ingress_sip_port (integer) Ingress SIP port. (default: cfg.profiles[].sip_port )
            # cfg.profiles[].egress_sip_port (integer) Egress SIP port. (default: 10000 + the Ingress SIP port )
            # cfg.profiles[].client (boolean) if true, transfers (REFER) are allowed on the egress (client-facing) profile. Default: false.

            # Ingress profile (carrier-side) is at port `sip_port`.

            q.name = q.context = "#{name}-ingress"
            q.sip_port = p.ingress_sip_port ? p.sip_port
            q.acl = q.name if cfg.acl_per_profile
            q.disable_transfer = true
            profile_module.call L, q

            # Egress profile (client-side) is at port 'sip_port+10000'.

            q.name = q.context = "#{name}-egress"
            q.sip_port = p.egress_sip_port ? 10000 + q.sip_port
            q.acl = q.name if cfg.acl_per_profile
            q.disable_transfer = q.client isnt true
            profile_module.call L, q

      configuration name:'httapi.conf', ->
        settings ->
        profiles ->
          # In mod_httapi.c/fetch_cache_data(), the profile_name might be set as a parameter, a setting, or defaults to `default`.
          profile name:'default', ->
            params ->
              # cfg.httapi_url (URL) URL for the HTTAPI service for FreeSwitch (default: '')
              # cfg.httapi_credentials (string) Credentials for the HTTAPI service for FreeSwitch (default: '')
              # cfg.httapi_authscheme (string) Authentication scheme for the HTTAPI service for FreeSwitch (default: 'basic')
              # cfg.httapi_cacert_check (boolean) Enable CA certificate check for the HTTAPI service for FreeSwitch (default: true)
              # cfg.httapi_verify_host (boolean) Enable host verification for the HTTAPI service for FreeSwitch (default: true)
              # cfg.httapi_timeout (integer) Timeout for the HTTAPI service for FreeSwitch (default: 120)
              param 'gateway-url', cfg.httapi_url ? ''
              param 'gateway-credentials', cfg.httapi_credentials ? ''
              param 'auth-scheme', cfg.httapi_authscheme ? 'basic'
              param 'enable-cacert-check', cfg.httapi_cacert_check ? true
              param 'enable-ssl-verifyhost', cfg.httpapi_verify_host ? true
              param 'timeout', cfg.httapi_timeout ? 120

    # cfg.sound_dir (string) Location of the sound files (default: `/opt/freeswitch/share/freeswitch/sounds`)
    sound_dir = cfg.sound_dir ? '/opt/freeswitch/share/freeswitch/sounds'
    section 'phrases', ->
      macros ->
        for module in phrases_to_load
          (module.include sound_dir) cfg
