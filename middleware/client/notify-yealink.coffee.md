      module.exports = notify_yealink = (socket,uri,to,new_messages,saved_messages) ->
        debug 'notify', {uri,to,new_messages,saved_messages}

        addresses = await resolve uri

        for address in addresses
          do (address) ->
            send_sip_notification socket, uri, to, new_messages,saved_messages, address.port, address.name

        debug 'notify done', {uri,to,new_messages,saved_messages}
        return



      send_sip_notification = (socket,uri,to,endpoint,message,target_port,target_name) ->
        body = Buffer.from """
          <?xml version="1.0"?>
          <YealinkIPPhoneStatus Beep="yes" Timeout="900">
          <Message>#{message}</Message>
          </YealinkIPPhoneStatus>
        """
        headers = Buffer.from """
          NOTIFY sip:#{uri} SIP/2.0
          Via: SIP/2.0/UDP #{target_name}:#{target_port};branch=0
          Max-Forwards: 2
          To: <sip:#{to}>
          From: <sip:#{to}>;tag=#{Math.random()}
          Call-ID: huge-play-#{Math.random()}
          CSeq: 1 NOTIFY
          Event: Yealink-xml
          Subscription-State: active
          Content-Type: application/xml
          Content-Length: #{body.length}
          X-En: #{endpoint}
          \n
        """.replace /\n/g, "\r\n"

        message = Buffer.allocUnsafe headers.length + body.length
        headers.copy message
        body.copy message, headers.length

        await new Promise (resolve,reject) ->
          socket.send message, 0, message.length, target_port, target_name, (error) ->
            if error
              reject error
            else
              resolve()
            return
        return

