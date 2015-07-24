    {expect} = require 'chai'

    it 'The FreeSwitch configuration should accept phrases', ->
      options = require './example.json'
      opts = {}
      for own k,v of options
        opts[k] = v
      opts.phrases = [
        require 'bumpy-lawyer/fr'
      ]
      config = (require '../conf/freeswitch') opts
      expect(config.match /<action function="play" data="voicemail\/vm-record_greeting.wav"\/>/)

    it 'The FreeSwitch configuration', ->
      options = require './example.json'
      config = (require '../conf/freeswitch') options

      expected_config = '''
        <?xml version="1.0" encoding="utf-8" ?>
        <document type="freeswitch/xml">
        <section name="configuration">
        <configuration name="switch.conf">
        <settings>
        <param name="switchname" value="freeswitch-server"/>
        <param name="core-db-name" value="/dev/shm/freeswitch/core-server.db"/>
        <param name="rtp-start-port" value="49152"/>
        <param name="rtp-end-port" value="65534"/>
        <param name="max-sessions" value="2000"/>
        <param name="sessions-per-second" value="2000"/>
        <param name="min-idle-cpu" value="1"/>
        <param name="loglevel" value="err"/>
        </settings>
        </configuration>
        <configuration name="modules.conf">
        <modules>
        <load module="mod_logfile"/>
        <load module="mod_event_socket"/>
        <load module="mod_commands"/>
        <load module="mod_dptools"/>
        <load module="mod_loopback"/>
        <load module="mod_dialplan_xml"/>
        <load module="mod_sofia"/>
        <load module="mod_sndfile"/>
        <load module="mod_tone_stream"/>
        <load module="mod_httapi"/>
        </modules>
        </configuration>
        <configuration name="logfile.conf">
        <settings>
        <param name="rotate-on-hup" value="true"/>
        </settings>
        <profiles>
        <profile name="default">
        <settings>
        <param name="logfile" value="log/freeswitch.log"/>
        <param name="rollover" value="10000000"/>
        <param name="uuid" value="true"/>
        </settings>
        <mappings>
        <map name="important" value="err,crit,alert"/>
        </mappings>
        </profile>
        </profiles>
        </configuration>
        <configuration name="event_socket.conf">
        <settings>
        <param name="nat-map" value="false"/>
        <param name="listen-ip" value="127.0.0.1"/>
        <param name="listen-port" value="5722"/>
        <param name="password" value="ClueCon"/>
        </settings>
        </configuration>
        <configuration name="acl.conf">
        <network-lists>
        <list name="default" default="deny">
        <node type="allow" cidr="172.17.42.0/8"/>
        <node type="allow" cidr="127.0.0.0/8"/>
        </list>
        </network-lists>
        </configuration>
        <configuration name="sofia.conf">
        <global_settings>
        <param name="log-level" value="1"/>
        <param name="debug-presence" value="0"/>
        </global_settings>
        <profiles>
        <profile name="huge-play-sbc-ingress">
        <settings>
        <param name="user-agent-string" value="huge-play-sbc-ingress-5080"/>
        <param name="username" value="huge-play-sbc-ingress"/>
        <param name="debug" value="2"/>
        <param name="sip-trace" value="false"/>
        <param name="sip-ip" value="auto"/>
        <param name="ext-sip-ip" value="auto"/>
        <param name="sip-port" value="5080"/>
        <param name="bind-params" value="transport=udp"/>
        <param name="apply-inbound-acl" value="default"/>
        <param name="disable-transfer" value="true"/>
        <param name="enable-3pcc" value="false"/>
        <param name="inbound-use-callid-as-uuid" value="true"/>
        <param name="outbound-use-uuid-as-callid" value="false"/>
        <param name="dialplan" value="XML"/>
        <param name="context" value="sbc-ingress"/>
        <param name="max-proceeding" value="3000"/>
        <param name="forward-unsolicited-mwi-notify" value="false"/>
        <param name="sip-options-respond-503-on-busy" value="false"/>
        <param name="timer-T1" value="250"/>
        <param name="timer-T1X64" value="16000"/>
        <param name="timer-T2" value="4000"/>
        <param name="timer-T4" value="5000"/>
        <param name="log-auth-failures" value="true"/>
        <param name="accept-blind-auth" value="true"/>
        <param name="auth-calls" value="false"/>
        <param name="auth-all-packets" value="false"/>
        <param name="nonce-ttl" value="60"/>
        <param name="pass-callee-id" value="false"/>
        <param name="caller-id-type" value="pid"/>
        <param name="manage-presence" value="false"/>
        <param name="manage-shared-appearance" value="false"/>
        <param name="disable-register" value="true"/>
        <param name="accept-blind-reg" value="false"/>
        <param name="NDLB-received-in-nat-reg-contact" value="false"/>
        <param name="all-reg-options-ping" value="false"/>
        <param name="nat-options-ping" value="false"/>
        <param name="rtp-ip" value="auto"/>
        <param name="ext-rtp-ip" value="auto"/>
        <param name="rtp-timeout-sec" value="300"/>
        <param name="rtp-hold-timeout-sec" value="1800"/>
        <param name="enable-soa" value="true"/>
        <param name="inbound-bypass-media" value="true"/>
        <param name="inbound-late-negotiation" value="true"/>
        <param name="inbound-proxy-media" value="false"/>
        <param name="media-option" value="bypass-media-after-att-xfer"/>
        <param name="inbound-zrtp-passthru" value="false"/>
        <param name="disable-transcoding" value="true"/>
        <param name="use-rtp-timer" value="true"/>
        <param name="rtp-timer-name" value="soft"/>
        <param name="auto-jitterbuffer-msec" value="60"/>
        <param name="auto-rtp-bugs" value="clear"/>
        <param name="inbound-codec-prefs" value="PCMA"/>
        <param name="outbound-codec-prefs" value="PCMA"/>
        <param name="inbound-codec-negotiation" value="scrooge"/>
        <param name="renegotiate-codec-on-reinvite" value="true"/>
        <param name="dtmf-type" value="rfc2833"/>
        <param name="rfc2833-pt" value="101"/>
        <param name="dtmf-duration" value="200"/>
        <param name="pass-rfc2833" value="true"/>
        <param name="aggressive-nat-detection" value="false"/>
        <param name="stun-enabled" value="false"/>
        <param name="stun-auto-disable" value="true"/>
        </settings>
        </profile>
        <profile name="huge-play-sbc-egress">
        <settings>
        <param name="user-agent-string" value="huge-play-sbc-egress-15080"/>
        <param name="username" value="huge-play-sbc-egress"/>
        <param name="debug" value="2"/>
        <param name="sip-trace" value="false"/>
        <param name="sip-ip" value="auto"/>
        <param name="ext-sip-ip" value="auto"/>
        <param name="sip-port" value="15080"/>
        <param name="bind-params" value="transport=udp"/>
        <param name="apply-inbound-acl" value="default"/>
        <param name="disable-transfer" value="true"/>
        <param name="enable-3pcc" value="false"/>
        <param name="inbound-use-callid-as-uuid" value="true"/>
        <param name="outbound-use-uuid-as-callid" value="false"/>
        <param name="dialplan" value="XML"/>
        <param name="context" value="sbc-egress"/>
        <param name="max-proceeding" value="3000"/>
        <param name="forward-unsolicited-mwi-notify" value="false"/>
        <param name="sip-options-respond-503-on-busy" value="false"/>
        <param name="timer-T1" value="250"/>
        <param name="timer-T1X64" value="16000"/>
        <param name="timer-T2" value="4000"/>
        <param name="timer-T4" value="5000"/>
        <param name="log-auth-failures" value="true"/>
        <param name="accept-blind-auth" value="true"/>
        <param name="auth-calls" value="false"/>
        <param name="auth-all-packets" value="false"/>
        <param name="nonce-ttl" value="60"/>
        <param name="pass-callee-id" value="false"/>
        <param name="caller-id-type" value="pid"/>
        <param name="manage-presence" value="false"/>
        <param name="manage-shared-appearance" value="false"/>
        <param name="disable-register" value="true"/>
        <param name="accept-blind-reg" value="false"/>
        <param name="NDLB-received-in-nat-reg-contact" value="false"/>
        <param name="all-reg-options-ping" value="false"/>
        <param name="nat-options-ping" value="false"/>
        <param name="rtp-ip" value="auto"/>
        <param name="ext-rtp-ip" value="auto"/>
        <param name="rtp-timeout-sec" value="300"/>
        <param name="rtp-hold-timeout-sec" value="1800"/>
        <param name="enable-soa" value="true"/>
        <param name="inbound-bypass-media" value="true"/>
        <param name="inbound-late-negotiation" value="true"/>
        <param name="inbound-proxy-media" value="false"/>
        <param name="media-option" value="bypass-media-after-att-xfer"/>
        <param name="inbound-zrtp-passthru" value="false"/>
        <param name="disable-transcoding" value="true"/>
        <param name="use-rtp-timer" value="true"/>
        <param name="rtp-timer-name" value="soft"/>
        <param name="auto-jitterbuffer-msec" value="60"/>
        <param name="auto-rtp-bugs" value="clear"/>
        <param name="inbound-codec-prefs" value="PCMA"/>
        <param name="outbound-codec-prefs" value="PCMA"/>
        <param name="inbound-codec-negotiation" value="scrooge"/>
        <param name="renegotiate-codec-on-reinvite" value="true"/>
        <param name="dtmf-type" value="rfc2833"/>
        <param name="rfc2833-pt" value="101"/>
        <param name="dtmf-duration" value="200"/>
        <param name="pass-rfc2833" value="true"/>
        <param name="aggressive-nat-detection" value="false"/>
        <param name="stun-enabled" value="false"/>
        <param name="stun-auto-disable" value="true"/>
        </settings>
        </profile>
        </profiles>
        </configuration>
        <configuration name="httapi.conf">
        <settings>
        </settings>
        <profiles>
        <profile name="default">
        <params>
        <param name="gateway-url" value=""/>
        <param name="gateway-credentials" value=""/>
        <param name="auth-scheme" value="basic"/>
        <param name="enable-cacert-check" value="true"/>
        <param name="enable-ssl-verifyhost" value="true"/>
        <param name="timeout" value="120"/>
        </params>
        </profile>
        </profiles>
        </configuration>
        </section>
        <section name="dialplan">
        <context name="sbc-ingress">
        <extension name="socket">
        <condition field="destination_number" expression="^.+$">
        <action application="multiset" data="direction=ingress profile=sbc"/>
        <action application="socket" data="127.0.0.1:5721 async full"/>
        </condition>
        </extension>
        <extension name="refer">
        <condition field="${sip_refer_to}" expression="^.+$">
        <action application="multiset" data="direction=ingress profile=sbc"/>
        <action application="socket" data="127.0.0.1:5721 async full"/>
        </condition>
        </extension>
        </context>
        <context name="sbc-egress">
        <extension name="socket">
        <condition field="destination_number" expression="^.+$">
        <action application="multiset" data="direction=egress profile=sbc"/>
        <action application="socket" data="127.0.0.1:5721 async full"/>
        </condition>
        </extension>
        <extension name="refer">
        <condition field="${sip_refer_to}" expression="^.+$">
        <action application="multiset" data="direction=egress profile=sbc"/>
        <action application="socket" data="127.0.0.1:5721 async full"/>
        </condition>
        </extension>
        </context>
        </section>
        <section name="phrases">
        <macros>
        <language name="fr" sound-path="/opt/freeswitch/sounds/fr/fr/sibylle">
        <macro name="say-single">
        <input pattern="^:$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/2.wav"/>
        <action function="play-file" data="digits/dot.wav"/>
        </match>
        </input>
        <input pattern="^([0-9])$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/$1.wav"/>
        </match>
        </input>
        <input pattern="^[*]$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/star.wav"/>
        </match>
        </input>
        <input pattern="^[#]$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/pound.wav"/>
        </match>
        </input>
        <input pattern="^[ ]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/32.wav"/>
        </match>
        </input>
        <input pattern="^[.]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/46.wav"/>
        </match>
        </input>
        <input pattern="^[@]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/64.wav"/>
        </match>
        </input>
        <input pattern="^[aA]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/97.wav"/>
        </match>
        </input>
        <input pattern="^[bB]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/98.wav"/>
        </match>
        </input>
        <input pattern="^[cC]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/99.wav"/>
        </match>
        </input>
        <input pattern="^[dD]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/100.wav"/>
        </match>
        </input>
        <input pattern="^[eE]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/101.wav"/>
        </match>
        </input>
        <input pattern="^[fF]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/102.wav"/>
        </match>
        </input>
        <input pattern="^[gG]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/103.wav"/>
        </match>
        </input>
        <input pattern="^[hH]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/104.wav"/>
        </match>
        </input>
        <input pattern="^[iI]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/105.wav"/>
        </match>
        </input>
        <input pattern="^[jJ]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/106.wav"/>
        </match>
        </input>
        <input pattern="^[kK]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/107.wav"/>
        </match>
        </input>
        <input pattern="^[lL]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/108.wav"/>
        </match>
        </input>
        <input pattern="^[mM]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/109.wav"/>
        </match>
        </input>
        <input pattern="^[nN]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/110.wav"/>
        </match>
        </input>
        <input pattern="^[oO]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/111.wav"/>
        </match>
        </input>
        <input pattern="^[pP]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/112.wav"/>
        </match>
        </input>
        <input pattern="^[qQ]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/113.wav"/>
        </match>
        </input>
        <input pattern="^[rR]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/114.wav"/>
        </match>
        </input>
        <input pattern="^[sS]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/115.wav"/>
        </match>
        </input>
        <input pattern="^[tT]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/116.wav"/>
        </match>
        </input>
        <input pattern="^[uU]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/117.wav"/>
        </match>
        </input>
        <input pattern="^[vV]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/118.wav"/>
        </match>
        </input>
        <input pattern="^[wW]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/119.wav"/>
        </match>
        </input>
        <input pattern="^[xX]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/120.wav"/>
        </match>
        </input>
        <input pattern="^[yY]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/121.wav"/>
        </match>
        </input>
        <input pattern="^[zZ]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/122.wav"/>
        </match>
        </input>
        </macro>
        <macro name="spell">
        <input pattern="^(.)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-single"/>
        </match>
        </input>
        <input pattern="^(.)(.+)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-single"/>
        <action function="phrase" data="$2" phrase="spell"/>
        </match>
        </input>
        </macro>
        <macro name="say-iterated">
        <input pattern="^([0-9.#,*])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-single"/>
        </match>
        </input>
        <input pattern="^([0-9.#,*])(.+)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-single"/>
        <action function="phrase" data="$2" phrase="say-iterated"/>
        </match>
        </input>
        </macro>
        <macro name="say-currency">
        <input pattern="^([0-9]+)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="currency/euro.wav"/>
        </match>
        </input>
        <input pattern="^([0-9]+)\\.0([0-9])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="currency/euro.wav"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        <action function="play-file" data="currency/cent.wav"/>
        </match>
        </input>
        <input pattern="^([0-9]+)\\.([1-9][0-9])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="currency/euro.wav"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        <action function="play-file" data="currency/cent.wav"/>
        </match>
        </input>
        </macro>
        <macro name="ip-addr">
        <input pattern="^([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="digits/dot.wav"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        <action function="play-file" data="digits/dot.wav"/>
        <action function="phrase" data="$3" phrase="say-number"/>
        <action function="play-file" data="digits/dot.wav"/>
        <action function="phrase" data="$4" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([0-9a-f]{1,4})(\\:.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-iterated"/>
        <action function="phrase" data="$2" phrase="ip-addr"/>
        </match>
        </input>
        <input pattern="^:([0-9a-f]{1,4})(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data=":" phrase="say"/>
        <action function="phrase" data="$1" phrase="say-iterated"/>
        <action function="phrase" data="$2" phrase="ip-addr"/>
        </match>
        </input>
        <input pattern="^::(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="::" phrase="ip-addr"/>
        <action function="phrase" data="$1" phrase="ip-addr"/>
        </match>
        </input>
        <input pattern="^::$" break_on_match="true">
        <match>
        <action function="phrase" data=":" phrase="say"/>
        <action function="phrase" data=":" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="say-counted" pause="1">
        <input pattern="^([1-9])_(0)$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/h-$1$2.wav"/>
        </match>
        </input>
        <input pattern="^(million|thousand|hundred)$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/h-$1.wav"/>
        </match>
        </input>
        <input pattern="^0+(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-counted"/>
        </match>
        </input>
        <input pattern="^([1-9]|[1-9][0-9]|[1-9][0-9][0-9])000000f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 counted million" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([1-9]|[1-9][0-9]|[1-9][0-9][0-9])([0-9]{6}f?n?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 million counted $2n" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1000f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="counted thousand" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9]|[1-9][0-9]|[1-9][0-9][0-9])000f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 counted thousand" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1([0-9]{3}f?n?)$" break_on_match="true">
        <match>
        <action function="phrase" data="thousand counted $1n" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9]|[1-9][0-9]|[1-9][0-9][0-9])([0-9]{3}f?n?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 thousand counted $2n" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^100f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="counted hundred" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9])00f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 counted hundred" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1([0-9][0-9]f?n?)$" break_on_match="true">
        <match>
        <action function="phrase" data="hundred counted $1n" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9])([0-9][0-9]f?n?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 hundred counted $2n" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1n$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/h-1n.wav"/>
        </match>
        </input>
        <input pattern="^1f$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/h-1f.wav"/>
        </match>
        </input>
        <input pattern="^([1-9]0|1[0-9]|[1-9])f?n?$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/h-$1.wav"/>
        </match>
        </input>
        <input pattern="^([23456])1f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1_0" phrase="say-number"/>
        <action function="play-file" data="digits/h-1n.wav"/>
        </match>
        </input>
        <input pattern="^([234568])([2-9])" break_on_match="true">
        <match>
        <action function="phrase" data="$1_0" phrase="say-number"/>
        <action function="play-file" data="digits/h-$2.wav"/>
        </match>
        </input>
        <input pattern="^71" break_on_match="true">
        <match>
        <action function="play-file" data="digits/60.wav"/>
        <action function="play-file" data="currency/and.wav"/>
        <action function="play-file" data="digits/h-11.wav"/>
        </match>
        </input>
        <input pattern="^7([02-9])" break_on_match="true">
        <match>
        <action function="play-file" data="digits/60.wav"/>
        <action function="play-file" data="digits/h-1$1.wav"/>
        </match>
        </input>
        <input pattern="^81" break_on_match="true">
        <match>
        <action function="play-file" data="digits/80.wav"/>
        <action function="play-file" data="digits/h-1n.wav"/>
        </match>
        </input>
        <input pattern="^9([1-9])" break_on_match="true">
        <match>
        <action function="play-file" data="digits/80.wav"/>
        <action function="play-file" data="digits/h-1$1.wav"/>
        </match>
        </input>
        </macro>
        <macro name="say-number" pause="1">
        <input pattern="^ +(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^iterated *([^ ]+)(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-iterated"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^counted *([^ ]+)(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-counted"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^(million|thousand|hundred|point) *(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/$1.wav"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([^ ]+) +(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^-(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="currency/minus.wav"/>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([1-9])_(0)$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/$1$2.wav"/>
        </match>
        </input>
        <input pattern="^([0-9]*)\\.([0]+)([1-9][0-9]*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 point iterated $2 $3" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([0-9]*)\\.([1-9][0-9]*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 point $2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^0f?$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/0.wav"/>
        </match>
        </input>
        <input pattern="^0+(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([1-9]|[1-9][0-9]|[1-9][0-9][0-9])000000f?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 million" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([1-9]|[1-9][0-9]|[1-9][0-9][0-9])([0-9]{6}f?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 million $2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1000f?$" break_on_match="true">
        <match>
        <action function="phrase" data="thousand" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9]|[1-9][0-9]|[1-9][0-9][0-9])000f?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 thousand" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1([0-9]{3}f?)$" break_on_match="true">
        <match>
        <action function="phrase" data="thousand $1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9]|[1-9][0-9]|[1-9][0-9][0-9])([0-9]{3}f?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 thousand $2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^100f?$" break_on_match="true">
        <match>
        <action function="phrase" data="hundred" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9])00f?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 hundred" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1([0-9][0-9]f?)$" break_on_match="true">
        <match>
        <action function="phrase" data="hundred $1$2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9])([0-9][0-9]f?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 hundred $2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1f$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/1f.wav"/>
        </match>
        </input>
        <input pattern="^([1-9]0|1[0-9]|[1-9])f?$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/$1.wav"/>
        </match>
        </input>
        <input pattern="^([234568])([2-9])" break_on_match="true">
        <match>
        <action function="phrase" data="$1_0" phrase="say-number"/>
        <action function="play-file" data="digits/$2.wav"/>
        </match>
        </input>
        <input pattern="^([234568])1f" break_on_match="true">
        <match>
        <action function="phrase" data="$1_0" phrase="say-number"/>
        <action function="play-file" data="currency/and.wav"/>
        <action function="play-file" data="digits/1f.wav"/>
        </match>
        </input>
        <input pattern="^(11|21|71|91)" break_on_match="true">
        <match>
        <action function="play-file" data="digits/$1.wav"/>
        </match>
        </input>
        <input pattern="^([23456])1" break_on_match="true">
        <match>
        <action function="phrase" data="$1_0" phrase="say-number"/>
        <action function="play-file" data="digits/x1.wav"/>
        </match>
        </input>
        <input pattern="^8(1.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/80.wav"/>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^7([02-9])" break_on_match="true">
        <match>
        <action function="phrase" data="60" phrase="say-number"/>
        <action function="phrase" data="1$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^9([0-9])" break_on_match="true">
        <match>
        <action function="phrase" data="80" phrase="say-number"/>
        <action function="phrase" data="1$1" phrase="say-number"/>
        </match>
        </input>
        </macro>
        <macro name="say-day-of-month">
        <input pattern="^0?1$" break_on_match="true">
        <match>
        <action function="phrase" data="1" phrase="say-counted"/>
        </match>
        </input>
        <input pattern="^0?([2-9])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([123][0-9])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        </macro>
        <macro name="say-month">
        <input pattern="^0?1$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-0.wav"/>
        </match>
        </input>
        <input pattern="^0?2$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-1.wav"/>
        </match>
        </input>
        <input pattern="^0?3$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-2.wav"/>
        </match>
        </input>
        <input pattern="^0?4$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-3.wav"/>
        </match>
        </input>
        <input pattern="^0?5$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-4.wav"/>
        </match>
        </input>
        <input pattern="^0?6$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-5.wav"/>
        </match>
        </input>
        <input pattern="^0?7$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-6.wav"/>
        </match>
        </input>
        <input pattern="^0?8$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-7.wav"/>
        </match>
        </input>
        <input pattern="^0?9$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-8.wav"/>
        </match>
        </input>
        <input pattern="^10$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-9.wav"/>
        </match>
        </input>
        <input pattern="^11$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-10.wav"/>
        </match>
        </input>
        <input pattern="^12$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-11.wav"/>
        </match>
        </input>
        </macro>
        <macro name="say-time">
        <input pattern="^([0-9]{2}):00" break_on_match="true">
        <match>
        <action function="phrase" data="$1f" phrase="say-number"/>
        <action function="play-file" data="time/hour.wav"/>
        </match>
        </input>
        <input pattern="^([0-9]{2}):([0-9]{2})" break_on_match="true">
        <match>
        <action function="phrase" data="$1f" phrase="say-number"/>
        <action function="play-file" data="time/hour.wav"/>
        <action function="phrase" data="$2f" phrase="say-number"/>
        </match>
        </input>
        </macro>
        <macro name="say">
        <input pattern="^(.*) +(iterated|pronounced)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-iterated"/>
        </match>
        </input>
        <input pattern="^(.*) +counted$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-counted"/>
        </match>
        </input>
        <input pattern="^(.*)( *€| +currency)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-currency"/>
        </match>
        </input>
        <input pattern="^0(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^(.*) masculine?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say"/>
        </match>
        </input>
        <input pattern="^(.)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-single"/>
        </match>
        </input>
        </macro>
        <macro name="vm_say">
        <input pattern="^sorry$" break_on_match="true">
        <match>
        <action function="play-file" data="misc/sorry.wav"/>
        </match>
        </input>
        <input pattern="^too short$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-too-small.wav"/>
        </match>
        </input>
        <input pattern="^thank you$" break_on_match="true">
        <match>
        <action function="play-file" data="ivr/ivr-thank_you_alt.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_enter_id">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-enter_id.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_enter_pass">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-enter_pass.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_fail_auth">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-fail_auth.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_hello">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="ivr/ivr-welcome.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_goodbye">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-goodbye.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_abort">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-abort.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_message_count">
        <input pattern="^([^:]+):urgent-new" break_on_match="true">
        <match>
        </match>
        </input>
        <input pattern="^0:new" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-you_have_neg.wav"/>
        <action function="play-file" data="more/none.wav"/>
        <action function="play-file" data="voicemail/vm-new.wav"/>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        </match>
        </input>
        <input pattern="^([^:]+):new" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-you_have.wav"/>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="voicemail/vm-new.wav"/>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        </match>
        </input>
        <input pattern="^0:saved" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-you_have_neg.wav"/>
        <action function="play-file" data="more/none.wav"/>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        <action function="play-file" data="voicemail/vm-urgent.wav"/>
        </match>
        </input>
        <input pattern="^([^:]+):saved" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-you_have.wav"/>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        <action function="play-file" data="voicemail/vm-urgent.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_menu">
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-listen_new.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-listen_saved.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-advanced.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$3 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-to_exit.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$4 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_config_menu">
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-to_record_greeting.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-record_name2.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$3 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-change_password.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$4 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-main_menu.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$5 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_record_name">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-record_name1.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_record_file_check">
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-listen_to_recording.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-save_recording.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-rerecord.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$3 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_record_urgent_check">
        <input pattern="^([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-mark-urgent.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-continue.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_forward_prepend">
        <input pattern="^([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-forward_add_intro.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-send_message_now.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_forward_message_enter_extension">
        <input pattern="^([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-forward_enter_ext.wav"/>
        <action function="play-file" data="voicemail/vm-followed_by.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_invalid_extension">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-that_was_an_invalid_ext.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_listen_file_check">
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1:$2:$3" phrase="voicemail_listen_file_check"/>
        <action function="play-file" data="voicemail/vm-forward_to_email.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$4 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-return_call.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$5 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-to_forward.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$6 pronounced" phrase="say"/>
        </match>
        </input>
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1:$2:$3" phrase="voicemail_listen_file_check"/>
        <action function="play-file" data="voicemail/vm-return_call.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$4 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-to_forward.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$5 pronounced" phrase="say"/>
        </match>
        </input>
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-listen_to_recording.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-save_recording.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-delete_recording.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$3 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_choose_greeting">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-choose_greeting_choose.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_choose_greeting_fail">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-choose_greeting_fail.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_record_greeting">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-record_greeting.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_record_message">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-record_message.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_greeting_selected">
        <input pattern="^(\\d+)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-greeting.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-selected.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_play_greeting">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-person.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-not_available.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_unavailable">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-not_available.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_say_number">
        <input pattern="^(\\d+)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_say_message_number">
        <input pattern="^([a-z]+):(\\d+)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-$1.wav"/>
        <action function="play-file" data="voicemail/vm-message_number.wav"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_say_phone_number">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_say_name">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_ack">
        <input pattern="^(too-small)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-too-small.wav"/>
        </match>
        </input>
        <input pattern="^(deleted|saved|emailed|marked-urgent)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        <action function="play-file" data="voicemail/vm-$1.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_say_date">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-date"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_disk_quota_exceeded">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-mailbox_full.wav"/>
        </match>
        </input>
        </macro>
        <macro name="valet_announce_ext">
        <input pattern="^([^\\:]+):(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="valet_lot_full">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="tone_stream://%(275,10,600);%(275,100,300)"/>
        </match>
        </input>
        </macro>
        <macro name="valet_lot_empty">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="tone_stream://%(275,10,600);%(275,100,300)"/>
        </match>
        </input>
        </macro>
        <macro name="message received">
        <input pattern="^([^:]+):([^:]*):[0-9]{4}-([0-9]{2})-([0-9]{2})T([0-9]{2}:[0-9]{2})" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-counted"/>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        <action function="play-file" data="voicemail/vm-received.wav"/>
        <action function="phrase" data="$4" phrase="say-day-of-month"/>
        <action function="phrase" data="$3" phrase="say-month"/>
        <action function="play-file" data="time/at.wav"/>
        <action function="phrase" data="$5" phrase="say-time"/>
        </match>
        </input>
        </macro>
        </language>
        <language name="fr-FR" sound-path="/opt/freeswitch/sounds/fr/fr/sibylle">
        <macro name="say-single">
        <input pattern="^:$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/2.wav"/>
        <action function="play-file" data="digits/dot.wav"/>
        </match>
        </input>
        <input pattern="^([0-9])$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/$1.wav"/>
        </match>
        </input>
        <input pattern="^[*]$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/star.wav"/>
        </match>
        </input>
        <input pattern="^[#]$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/pound.wav"/>
        </match>
        </input>
        <input pattern="^[ ]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/32.wav"/>
        </match>
        </input>
        <input pattern="^[.]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/46.wav"/>
        </match>
        </input>
        <input pattern="^[@]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/64.wav"/>
        </match>
        </input>
        <input pattern="^[aA]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/97.wav"/>
        </match>
        </input>
        <input pattern="^[bB]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/98.wav"/>
        </match>
        </input>
        <input pattern="^[cC]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/99.wav"/>
        </match>
        </input>
        <input pattern="^[dD]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/100.wav"/>
        </match>
        </input>
        <input pattern="^[eE]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/101.wav"/>
        </match>
        </input>
        <input pattern="^[fF]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/102.wav"/>
        </match>
        </input>
        <input pattern="^[gG]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/103.wav"/>
        </match>
        </input>
        <input pattern="^[hH]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/104.wav"/>
        </match>
        </input>
        <input pattern="^[iI]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/105.wav"/>
        </match>
        </input>
        <input pattern="^[jJ]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/106.wav"/>
        </match>
        </input>
        <input pattern="^[kK]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/107.wav"/>
        </match>
        </input>
        <input pattern="^[lL]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/108.wav"/>
        </match>
        </input>
        <input pattern="^[mM]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/109.wav"/>
        </match>
        </input>
        <input pattern="^[nN]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/110.wav"/>
        </match>
        </input>
        <input pattern="^[oO]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/111.wav"/>
        </match>
        </input>
        <input pattern="^[pP]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/112.wav"/>
        </match>
        </input>
        <input pattern="^[qQ]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/113.wav"/>
        </match>
        </input>
        <input pattern="^[rR]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/114.wav"/>
        </match>
        </input>
        <input pattern="^[sS]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/115.wav"/>
        </match>
        </input>
        <input pattern="^[tT]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/116.wav"/>
        </match>
        </input>
        <input pattern="^[uU]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/117.wav"/>
        </match>
        </input>
        <input pattern="^[vV]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/118.wav"/>
        </match>
        </input>
        <input pattern="^[wW]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/119.wav"/>
        </match>
        </input>
        <input pattern="^[xX]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/120.wav"/>
        </match>
        </input>
        <input pattern="^[yY]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/121.wav"/>
        </match>
        </input>
        <input pattern="^[zZ]$" break_on_match="true">
        <match>
        <action function="play-file" data="phonetic-ascii/122.wav"/>
        </match>
        </input>
        </macro>
        <macro name="spell">
        <input pattern="^(.)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-single"/>
        </match>
        </input>
        <input pattern="^(.)(.+)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-single"/>
        <action function="phrase" data="$2" phrase="spell"/>
        </match>
        </input>
        </macro>
        <macro name="say-iterated">
        <input pattern="^([0-9.#,*])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-single"/>
        </match>
        </input>
        <input pattern="^([0-9.#,*])(.+)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-single"/>
        <action function="phrase" data="$2" phrase="say-iterated"/>
        </match>
        </input>
        </macro>
        <macro name="say-currency">
        <input pattern="^([0-9]+)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="currency/euro.wav"/>
        </match>
        </input>
        <input pattern="^([0-9]+)\\.0([0-9])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="currency/euro.wav"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        <action function="play-file" data="currency/cent.wav"/>
        </match>
        </input>
        <input pattern="^([0-9]+)\\.([1-9][0-9])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="currency/euro.wav"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        <action function="play-file" data="currency/cent.wav"/>
        </match>
        </input>
        </macro>
        <macro name="ip-addr">
        <input pattern="^([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="digits/dot.wav"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        <action function="play-file" data="digits/dot.wav"/>
        <action function="phrase" data="$3" phrase="say-number"/>
        <action function="play-file" data="digits/dot.wav"/>
        <action function="phrase" data="$4" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([0-9a-f]{1,4})(\\:.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-iterated"/>
        <action function="phrase" data="$2" phrase="ip-addr"/>
        </match>
        </input>
        <input pattern="^:([0-9a-f]{1,4})(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data=":" phrase="say"/>
        <action function="phrase" data="$1" phrase="say-iterated"/>
        <action function="phrase" data="$2" phrase="ip-addr"/>
        </match>
        </input>
        <input pattern="^::(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="::" phrase="ip-addr"/>
        <action function="phrase" data="$1" phrase="ip-addr"/>
        </match>
        </input>
        <input pattern="^::$" break_on_match="true">
        <match>
        <action function="phrase" data=":" phrase="say"/>
        <action function="phrase" data=":" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="say-counted" pause="1">
        <input pattern="^([1-9])_(0)$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/h-$1$2.wav"/>
        </match>
        </input>
        <input pattern="^(million|thousand|hundred)$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/h-$1.wav"/>
        </match>
        </input>
        <input pattern="^0+(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-counted"/>
        </match>
        </input>
        <input pattern="^([1-9]|[1-9][0-9]|[1-9][0-9][0-9])000000f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 counted million" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([1-9]|[1-9][0-9]|[1-9][0-9][0-9])([0-9]{6}f?n?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 million counted $2n" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1000f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="counted thousand" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9]|[1-9][0-9]|[1-9][0-9][0-9])000f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 counted thousand" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1([0-9]{3}f?n?)$" break_on_match="true">
        <match>
        <action function="phrase" data="thousand counted $1n" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9]|[1-9][0-9]|[1-9][0-9][0-9])([0-9]{3}f?n?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 thousand counted $2n" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^100f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="counted hundred" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9])00f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 counted hundred" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1([0-9][0-9]f?n?)$" break_on_match="true">
        <match>
        <action function="phrase" data="hundred counted $1n" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9])([0-9][0-9]f?n?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 hundred counted $2n" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1n$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/h-1n.wav"/>
        </match>
        </input>
        <input pattern="^1f$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/h-1f.wav"/>
        </match>
        </input>
        <input pattern="^([1-9]0|1[0-9]|[1-9])f?n?$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/h-$1.wav"/>
        </match>
        </input>
        <input pattern="^([23456])1f?n?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1_0" phrase="say-number"/>
        <action function="play-file" data="digits/h-1n.wav"/>
        </match>
        </input>
        <input pattern="^([234568])([2-9])" break_on_match="true">
        <match>
        <action function="phrase" data="$1_0" phrase="say-number"/>
        <action function="play-file" data="digits/h-$2.wav"/>
        </match>
        </input>
        <input pattern="^71" break_on_match="true">
        <match>
        <action function="play-file" data="digits/60.wav"/>
        <action function="play-file" data="currency/and.wav"/>
        <action function="play-file" data="digits/h-11.wav"/>
        </match>
        </input>
        <input pattern="^7([02-9])" break_on_match="true">
        <match>
        <action function="play-file" data="digits/60.wav"/>
        <action function="play-file" data="digits/h-1$1.wav"/>
        </match>
        </input>
        <input pattern="^81" break_on_match="true">
        <match>
        <action function="play-file" data="digits/80.wav"/>
        <action function="play-file" data="digits/h-1n.wav"/>
        </match>
        </input>
        <input pattern="^9([1-9])" break_on_match="true">
        <match>
        <action function="play-file" data="digits/80.wav"/>
        <action function="play-file" data="digits/h-1$1.wav"/>
        </match>
        </input>
        </macro>
        <macro name="say-number" pause="1">
        <input pattern="^ +(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^iterated *([^ ]+)(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-iterated"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^counted *([^ ]+)(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-counted"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^(million|thousand|hundred|point) *(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/$1.wav"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([^ ]+) +(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^-(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="currency/minus.wav"/>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([1-9])_(0)$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/$1$2.wav"/>
        </match>
        </input>
        <input pattern="^([0-9]*)\\.([0]+)([1-9][0-9]*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 point iterated $2 $3" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([0-9]*)\\.([1-9][0-9]*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 point $2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^0f?$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/0.wav"/>
        </match>
        </input>
        <input pattern="^0+(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([1-9]|[1-9][0-9]|[1-9][0-9][0-9])000000f?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 million" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([1-9]|[1-9][0-9]|[1-9][0-9][0-9])([0-9]{6}f?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 million $2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1000f?$" break_on_match="true">
        <match>
        <action function="phrase" data="thousand" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9]|[1-9][0-9]|[1-9][0-9][0-9])000f?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 thousand" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1([0-9]{3}f?)$" break_on_match="true">
        <match>
        <action function="phrase" data="thousand $1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9]|[1-9][0-9]|[1-9][0-9][0-9])([0-9]{3}f?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 thousand $2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^100f?$" break_on_match="true">
        <match>
        <action function="phrase" data="hundred" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9])00f?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 hundred" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1([0-9][0-9]f?)$" break_on_match="true">
        <match>
        <action function="phrase" data="hundred $1$2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([2-9])([0-9][0-9]f?)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 hundred $2" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^1f$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/1f.wav"/>
        </match>
        </input>
        <input pattern="^([1-9]0|1[0-9]|[1-9])f?$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/$1.wav"/>
        </match>
        </input>
        <input pattern="^([234568])([2-9])" break_on_match="true">
        <match>
        <action function="phrase" data="$1_0" phrase="say-number"/>
        <action function="play-file" data="digits/$2.wav"/>
        </match>
        </input>
        <input pattern="^([234568])1f" break_on_match="true">
        <match>
        <action function="phrase" data="$1_0" phrase="say-number"/>
        <action function="play-file" data="currency/and.wav"/>
        <action function="play-file" data="digits/1f.wav"/>
        </match>
        </input>
        <input pattern="^(11|21|71|91)" break_on_match="true">
        <match>
        <action function="play-file" data="digits/$1.wav"/>
        </match>
        </input>
        <input pattern="^([23456])1" break_on_match="true">
        <match>
        <action function="phrase" data="$1_0" phrase="say-number"/>
        <action function="play-file" data="digits/x1.wav"/>
        </match>
        </input>
        <input pattern="^8(1.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="digits/80.wav"/>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^7([02-9])" break_on_match="true">
        <match>
        <action function="phrase" data="60" phrase="say-number"/>
        <action function="phrase" data="1$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^9([0-9])" break_on_match="true">
        <match>
        <action function="phrase" data="80" phrase="say-number"/>
        <action function="phrase" data="1$1" phrase="say-number"/>
        </match>
        </input>
        </macro>
        <macro name="say-day-of-month">
        <input pattern="^0?1$" break_on_match="true">
        <match>
        <action function="phrase" data="1" phrase="say-counted"/>
        </match>
        </input>
        <input pattern="^0?([2-9])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^([123][0-9])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        </macro>
        <macro name="say-month">
        <input pattern="^0?1$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-0.wav"/>
        </match>
        </input>
        <input pattern="^0?2$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-1.wav"/>
        </match>
        </input>
        <input pattern="^0?3$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-2.wav"/>
        </match>
        </input>
        <input pattern="^0?4$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-3.wav"/>
        </match>
        </input>
        <input pattern="^0?5$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-4.wav"/>
        </match>
        </input>
        <input pattern="^0?6$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-5.wav"/>
        </match>
        </input>
        <input pattern="^0?7$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-6.wav"/>
        </match>
        </input>
        <input pattern="^0?8$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-7.wav"/>
        </match>
        </input>
        <input pattern="^0?9$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-8.wav"/>
        </match>
        </input>
        <input pattern="^10$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-9.wav"/>
        </match>
        </input>
        <input pattern="^11$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-10.wav"/>
        </match>
        </input>
        <input pattern="^12$" break_on_match="true">
        <match>
        <action function="play-file" data="time/mon-11.wav"/>
        </match>
        </input>
        </macro>
        <macro name="say-time">
        <input pattern="^([0-9]{2}):00" break_on_match="true">
        <match>
        <action function="phrase" data="$1f" phrase="say-number"/>
        <action function="play-file" data="time/hour.wav"/>
        </match>
        </input>
        <input pattern="^([0-9]{2}):([0-9]{2})" break_on_match="true">
        <match>
        <action function="phrase" data="$1f" phrase="say-number"/>
        <action function="play-file" data="time/hour.wav"/>
        <action function="phrase" data="$2f" phrase="say-number"/>
        </match>
        </input>
        </macro>
        <macro name="say">
        <input pattern="^(.*) +(iterated|pronounced)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-iterated"/>
        </match>
        </input>
        <input pattern="^(.*) +counted$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-counted"/>
        </match>
        </input>
        <input pattern="^(.*)( *€| +currency)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-currency"/>
        </match>
        </input>
        <input pattern="^0(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-number"/>
        </match>
        </input>
        <input pattern="^(.*) masculine?$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say"/>
        </match>
        </input>
        <input pattern="^(.)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-single"/>
        </match>
        </input>
        </macro>
        <macro name="vm_say">
        <input pattern="^sorry$" break_on_match="true">
        <match>
        <action function="play-file" data="misc/sorry.wav"/>
        </match>
        </input>
        <input pattern="^too short$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-too-small.wav"/>
        </match>
        </input>
        <input pattern="^thank you$" break_on_match="true">
        <match>
        <action function="play-file" data="ivr/ivr-thank_you_alt.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_enter_id">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-enter_id.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_enter_pass">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-enter_pass.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_fail_auth">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-fail_auth.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_hello">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="ivr/ivr-welcome.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_goodbye">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-goodbye.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_abort">
        <input pattern="(.*)" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-abort.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_message_count">
        <input pattern="^([^:]+):urgent-new" break_on_match="true">
        <match>
        </match>
        </input>
        <input pattern="^0:new" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-you_have_neg.wav"/>
        <action function="play-file" data="more/none.wav"/>
        <action function="play-file" data="voicemail/vm-new.wav"/>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        </match>
        </input>
        <input pattern="^([^:]+):new" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-you_have.wav"/>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="voicemail/vm-new.wav"/>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        </match>
        </input>
        <input pattern="^0:saved" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-you_have_neg.wav"/>
        <action function="play-file" data="more/none.wav"/>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        <action function="play-file" data="voicemail/vm-urgent.wav"/>
        </match>
        </input>
        <input pattern="^([^:]+):saved" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-you_have.wav"/>
        <action function="phrase" data="$1" phrase="say-number"/>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        <action function="play-file" data="voicemail/vm-urgent.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_menu">
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-listen_new.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-listen_saved.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-advanced.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$3 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-to_exit.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$4 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_config_menu">
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-to_record_greeting.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-record_name2.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$3 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-change_password.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$4 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-main_menu.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$5 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_record_name">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-record_name1.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_record_file_check">
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-listen_to_recording.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-save_recording.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-rerecord.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$3 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_record_urgent_check">
        <input pattern="^([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-mark-urgent.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-continue.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_forward_prepend">
        <input pattern="^([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-forward_add_intro.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-send_message_now.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_forward_message_enter_extension">
        <input pattern="^([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-forward_enter_ext.wav"/>
        <action function="play-file" data="voicemail/vm-followed_by.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_invalid_extension">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-that_was_an_invalid_ext.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_listen_file_check">
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1:$2:$3" phrase="voicemail_listen_file_check"/>
        <action function="play-file" data="voicemail/vm-forward_to_email.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$4 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-return_call.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$5 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-to_forward.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$6 pronounced" phrase="say"/>
        </match>
        </input>
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="phrase" data="$1:$2:$3" phrase="voicemail_listen_file_check"/>
        <action function="play-file" data="voicemail/vm-return_call.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$4 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-to_forward.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$5 pronounced" phrase="say"/>
        </match>
        </input>
        <input pattern="^([0-9#*]):([0-9#*]):([0-9#*])$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-listen_to_recording.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-save_recording.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-delete_recording.wav"/>
        <action function="play-file" data="voicemail/vm-press.wav"/>
        <action function="phrase" data="$3 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_choose_greeting">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-choose_greeting_choose.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_choose_greeting_fail">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-choose_greeting_fail.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_record_greeting">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-record_greeting.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_record_message">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-record_message.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_greeting_selected">
        <input pattern="^(\\d+)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-greeting.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-selected.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_play_greeting">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-person.wav"/>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        <action function="play-file" data="voicemail/vm-not_available.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_unavailable">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-not_available.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_say_number">
        <input pattern="^(\\d+)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_say_message_number">
        <input pattern="^([a-z]+):(\\d+)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-$1.wav"/>
        <action function="play-file" data="voicemail/vm-message_number.wav"/>
        <action function="phrase" data="$2" phrase="say-number"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_say_phone_number">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_say_name">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_ack">
        <input pattern="^(too-small)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-too-small.wav"/>
        </match>
        </input>
        <input pattern="^(deleted|saved|emailed|marked-urgent)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        <action function="play-file" data="voicemail/vm-$1.wav"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_say_date">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-date"/>
        </match>
        </input>
        </macro>
        <macro name="voicemail_disk_quota_exceeded">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="voicemail/vm-mailbox_full.wav"/>
        </match>
        </input>
        </macro>
        <macro name="valet_announce_ext">
        <input pattern="^([^\\:]+):(.*)$" break_on_match="true">
        <match>
        <action function="phrase" data="$2 pronounced" phrase="say"/>
        </match>
        </input>
        </macro>
        <macro name="valet_lot_full">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="tone_stream://%(275,10,600);%(275,100,300)"/>
        </match>
        </input>
        </macro>
        <macro name="valet_lot_empty">
        <input pattern="^(.*)$" break_on_match="true">
        <match>
        <action function="play-file" data="tone_stream://%(275,10,600);%(275,100,300)"/>
        </match>
        </input>
        </macro>
        <macro name="message received">
        <input pattern="^([^:]+):([^:]*):[0-9]{4}-([0-9]{2})-([0-9]{2})T([0-9]{2}:[0-9]{2})" break_on_match="true">
        <match>
        <action function="phrase" data="$1" phrase="say-counted"/>
        <action function="play-file" data="voicemail/vm-message.wav"/>
        <action function="play-file" data="voicemail/vm-received.wav"/>
        <action function="phrase" data="$4" phrase="say-day-of-month"/>
        <action function="phrase" data="$3" phrase="say-month"/>
        <action function="play-file" data="time/at.wav"/>
        <action function="phrase" data="$5" phrase="say-time"/>
        </match>
        </input>
        </macro>
        </language>
        </macros>
        </section>
        </document>

      '''.replace /\n */g, '\n'

      expect(config).to.equal expected_config
