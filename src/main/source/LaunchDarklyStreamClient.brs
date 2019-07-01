function LaunchDarklyStreamClient(config as Object, store as Object, messagePort as Object, user as Object) as Object
    this = {
        private: {
            config: config,
            store: store,
            messagePort: messagePort,
            user: user,
            util: LaunchDarklyUtility(),

            stageMap: {
                notStarted: 0,
                handshake: 1,
                sendingRequest: 2,
                readingHeader: 3,
                readingBody: 4,
                unauthorized: 5
            },
            stage: 0,

            streamCrypto: invalid,
            streamRequestSent: invalid,
            streamRequestContent: invalid,
            streamSocket: invalid,
            streamHTTP: invalid,
            streamSSE: invalid,
            streamBackoff: LaunchDarklyBackoff(),
            streamTCPTimer: createObject("roTimeSpan"),

            handshakeTransfer: createObject("roUrlTransfer"),

            startHandshakeTransfer: function() as Void
                if m.config.private.offline = false then
                    m.config.private.logger.debug("stream client starting handshake transfer")

                    user = FormatJSON(m.user.private.encode(false))
                    m.handshakeTransfer.asyncPostFromString(user)
                    m.stage = m.stageMap.handshake
                end if
            end function,

            prepareHandshakeTransfer: function() as Void
                url = m.config.private.streamURI + "/handshake"

                m.config.private.logger.debug("handshake url: " + url)

                m.util.prepareNetworkingCommon(m.messagePort, m.config, m.handshakeTransfer)
                m.handshakeTransfer.addHeader("Content-Type", "application/json")
                m.handshakeTransfer.setURL(url)
            end function,

            killStream: function() as Void
                m.stage = m.stageMap.notStarted
                m.streamSocket = invalid
            end function,

            killFailedStream: function() as Void
                m.killStream()
                m.streamBackoff.fail()
            end function,

            runTCPStep: function() as Void
                if m.streamSocket.isReadable() then
                    m.config.private.logger.debug("socket readable")

                    while true
                        responseBinary = createObject("roByteArray")
                        responseBinary[512] = 0

                        status = m.streamSocket.receive(responseBinary, 0, 512)

                        if status = -1 then
                            m.config.private.logger.debug("socket must wait to read")

                            exit while
                        else if status = 0 then
                            m.killFailedStream()

                            m.config.private.logger.debug("socket closed")

                            return
                        else if status > 0 then
                            m.config.private.logger.debug("socket received bytes " + status.toStr())

                            m.streamTCPTimer.mark()

                            responseBinaryCopy = createObject("roByteArray")
                            responseBinaryCopy.setResize(status, false)

                            m.util.memcpy(responseBinary, 0, responseBinaryCopy, 0, status)

                            m.streamHTTP.addBytes(responseBinaryCopy)

                            if m.runHTTPStep() = false then
                                return
                            end if
                        end if
                    end while
                end if
            end function,

            runHTTPStep: function() as Boolean
                while true
                    chunk = m.streamHTTP.streamHTTP()

                    if m.streamHTTP.responseStatus < 0 then
                        errorText = m.streamCrypto.responseStatusText()
                        m.config.private.logger.error("http stream: " + errorText)
                        m.killFailedStream()

                        return false
                    else if m.streamHTTP.responseStatus >= 1 AND m.stage = m.stageMap.readingHeader then
                        code = m.streamHTTP.responseCode

                        m.config.private.logger.debug("stream response code: " + code.toStr())

                        if code = 401 OR code = 403 then
                            m.config.private.logger.error("streaming not authorized")

                            m.killStream()
                            m.status = m.stageMap.unauthorized

                            return false
                        else if code < 200 OR code >= 300 then
                            m.config.private.logger.warn("stream http request fail")

                            m.killFailedStream()

                            return false
                        else
                            m.streamBackoff.success()
                        end if

                        m.stage = m.stageMap.readingBody
                    end if

                    if chunk = invalid then
                        m.config.private.logger.debug("http stream no chunk")
                        return true
                    else
                        m.config.private.logger.debug("http stream got chunk")
                        m.streamCrypto.addBytes(chunk)

                        if m.runCryptoStep() = false then
                            return false
                        end if
                    end if
                end while
            end function,

            runCryptoStep: function() as Boolean
                while true
                    plainText = m.streamCrypto.consumeEvent()

                    if m.streamCrypto.getErrorCode() <> 0 then
                        errorText = m.streamCrypto.getErrorString()
                        m.config.private.logger.error("crypto stream error: " + errorText)
                        m.killFailedStream()

                        return false
                    end if

                    if plainText = invalid then
                        m.config.private.logger.debug("crypto stream no plaintext")
                        return true
                    else
                        m.config.private.logger.debug("crypto stream got plaintext")

                        m.streamSSE.addChunk(plainText.toAsciiString())

                        if m.runSSEStep() = false then
                            return false
                        end if
                    end if
                end while
            end function

            runSSEStep: function() as Boolean
                while true
                    event = m.streamSSE.consumeEvent()

                    if event = invalid then
                        m.config.private.logger.debug("SSE stream no event")
                        return true
                    else
                        m.config.private.logger.debug("SSE stream got event: " + event.name)

                        body = parseJSON(event.value)

                        if body = invalid then
                            m.config.private.logger.error("SSE stream failed to parse JSON")
                            m.killFailedStream()
                            return false
                        end if

                        if event.name = "put" then
                            m.store.putAll(body)
                        else if event.name = "patch" then
                            m.store.upsert(body)
                        end if
                    end if
                end while
            end function

            handleStreamMessage: function(message as Dynamic) as Void
                m.config.private.logger.debug("socket event")

                if m.streamSocket = invalid then
                    m.config.private.logger.error("handleStreamMessage called without socket available")
                    return
                end if

                if m.stage = m.stageMap.sendingRequest then
                    if m.streamSocket.isWritable() then
                        m.config.private.logger.debug("socket writable")

                        while true
                            if m.streamRequestSent = m.streamRequestContent.count() then
                                m.config.private.logger.debug("http request sent")
                                m.stage = m.stageMap.readingHeader
                                m.streamSocket.notifyWritable(false)
                                exit while
                            end if

                            status = m.streamSocket.send(m.streamRequestContent, m.streamRequestSent, m.streamRequestContent.count() - m.streamRequestSent)

                            if status = -1 then
                                m.config.private.logger.debug("socket must wait to write")
                                exit while
                            else if status = 0 then
                                m.config.private.logger.debug("socket closed")
                                m.killFailedStream()
                                return
                            else if status > 0 then
                                m.config.private.logger.debug("socket sent bytes " + status.toStr())

                                m.streamTCPTimer.mark()

                                m.streamRequestSent += status
                            end if
                        end while
                    end if
                end if

                if m.stage = m.stageMap.readingHeader OR m.stage = m.stageMap.readingBody then
                    m.runTCPStep()
                end if
            end function,

            handleHandshakeMessage: function(message as Dynamic) as Void
                responseCode = message.getResponseCode()

                m.config.private.logger.debug("handshake response code: " + responseCode.toStr())

                if responseCode = 401 OR responseCode = 403 then
                    m.config.private.logger.error("streaming handshake not authorized")

                    m.status = m.stageMap.unauthorized

                    return
                else if responseCode < 200 OR responseCode >= 300 then
                    m.config.private.logger.error("streaming handshake not successful")

                    m.killFailedStream()

                    return
                end if

                decoded = parseJSON(message.getString())

                if decoded = invalid then
                    m.config.private.logger.error("failed json decoding")

                    m.killFailedStream()

                    return
                end if

                m.config.private.logger.debug("got shared secret")

                cipherKeyBuffer = decoded.cipherKey
                authKeyBuffer = decoded.authenticationKey

                cipherKey = createObject("roByteArray")
                cipherKey.fromBase64String(decoded.cipherKey)

                authKey = createObject("roByteArray")
                authKey.fromBase64String(decoded.authenticationKey)

                bundle = createObject("roByteArray")
                bundle.fromBase64String(decoded.serverBundle)

                requestText = ""
                requestText += "POST /stream HTTP/1.1" + chr(13) + chr(10)
                requestText += "User-Agent: RokuClient/" + m.config.private.sdkVersion + chr(13) + chr(10)
                requestText += "Content-Length: " + bundle.count().toStr() + chr(13) + chr(10)
                requestText += "Connection: close" + chr(13) + chr(10)
                requestText += chr(13) + chr(10)

                m.streamCrypto = LaunchDarklyCryptoReader(cipherKey, authKey)

                m.streamRequestContent = createObject("roByteArray")
                m.streamRequestContent.fromAsciiString(requestText)
                m.streamRequestContent.append(bundle)

                address = mid(m.config.private.streamURI, 8)
                sendAddress = createObject("roSocketAddress")
                sendAddress.SetAddress(address)
                socket = createObject("roStreamSocket")
                socket.setSendToAddress(sendAddress)
                socket.setMessagePort(m.messagePort)
                socket.notifyReadable(true)
                socket.notifyWritable(true)
                socket.setKeepAlive(true)

                m.streamSocket = socket
                m.streamHTTP = LaunchDarklyHTTPResponse()
                m.streamSSE = LaunchDarklySSE()
                m.streamRequestSent = 0
                m.streamTCPTimer.mark()

                if socket.connect() then
                    m.config.private.logger.debug("streaming socket connection success")
                    m.stage = m.stageMap.sendingRequest
                else
                    m.config.private.logger.error("streaming socket connection failure")
                    m.killFailedStream()
                end if
            end function,
        },

        handleMessage: function(message=invalid as Dynamic) as Boolean
            if m.private.streamTCPTimer.totalSeconds() > 60 * 5 then
                m.private.killStream()
            end if

            REM start stream if it is not active
            if m.private.config.private.streaming AND m.private.stage = m.private.stageMap.notStarted then
                if m.private.streamBackoff.shouldWait() = false then
                    m.private.config.private.logger.debug("streaming timeout hit")

                    m.private.startHandshakeTransfer()
                else
                    m.private.config.private.logger.debug("waiting on stream retry")
                end if
            end if

            if type(message) = "roUrlEvent" then
                eventId = message.getSourceIdentity()
                handshakeId = m.private.handshakeTransfer.getIdentity()

                if eventId = handshakeId then
                    m.private.handleHandshakeMessage(message)

                    return true
                end if
            else if type(message) = "roSocketEvent" then
                if message.getSocketID() = m.private.streamSocket.getID() then
                    m.private.handleStreamMessage(message)

                    return true
                end if
            end if

            return false
        end function,

        changeUser: function(user as Object)
            m.private.config.private.logger.debug("stream client switching user")

            m.private.user = user
            m.private.killStream()
            m.handleMessage(invalid)
        end function
    }

    this.private.prepareHandshakeTransfer()
    this.handleMessage(invalid)

    return this
end function
