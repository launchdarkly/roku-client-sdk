function LaunchDarklyStreamClient(launchDarklyParamConfig as Object, launchDarklyParamStore as Object, launchDarklyParamMessagePort as Object, context as Object, launchDarklyParamStatus as Object) as Object
    launchDarklyLocalThis = {
        private: {
            config: launchDarklyParamConfig,
            store: launchDarklyParamStore,
            messagePort: launchDarklyParamMessagePort,
            context: context,
            util: launchDarklyUtility(),

            stageMap: {
                notStarted: 0,
                handshake: 1,
                sendingRequest: 2,
                readingHeader: 3,
                readingBody: 4
            },
            stage: 0,

            status: launchDarklyParamStatus,

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

                    encodedContext = FormatJSON(LaunchDarklyContextEncode(m.context, false))
                    m.handshakeTransfer.asyncPostFromString(encodedContext)
                    m.stage = m.stageMap.handshake

                    m.streamBackoff.started()
                end if
            end function,

            prepareHandshakeTransfer: function() as Void
                launchDarklyLocalUrl = m.config.private.streamURI + "/handshake"

                if m.config.private.useReasons then
                    launchDarklyLocalUrl += "?withReasons=true"
                end if

                m.config.private.logger.debug("handshake url: " + launchDarklyLocalUrl)

                defaultStreamHeaders = {
                  "Content-Type": "application/json",
                  "X-LaunchDarkly-AltStream-Version": "2"
                }
                m.util.prepareNetworkingCommon(m.messagePort, m.config, m.handshakeTransfer, defaultStreamHeaders)
                m.handshakeTransfer.setURL(launchDarklyLocalUrl)
            end function,

            killStream: function() as Void
                m.stage = m.stageMap.notStarted
                m.streamSocket = invalid
                m.handshakeTransfer.asyncCancel()
                m.streamBackoff.finished()
            end function,

            runTCPStep: function() as Void
                if m.streamSocket.isReadable() then
                    m.config.private.logger.debug("socket readable")

                    while true
                        launchDarklyLocalResponseBinary = createObject("roByteArray")
                        launchDarklyLocalResponseBinary[512] = 0

                        launchDarklyLocalStatus = m.streamSocket.receive(launchDarklyLocalResponseBinary, 0, 512)

                        if launchDarklyLocalStatus = -1 then
                            m.config.private.logger.debug("socket must wait to read")

                            exit while
                        else if launchDarklyLocalStatus = 0 then
                            m.killStream()

                            m.config.private.logger.debug("socket closed")

                            return
                        else if launchDarklyLocalStatus > 0 then
                            m.config.private.logger.debug("socket received bytes " + launchDarklyLocalStatus.toStr())

                            m.streamTCPTimer.mark()

                            launchDarklyLocalResponseBinaryCopy = createObject("roByteArray")
                            launchDarklyLocalResponseBinaryCopy.setResize(launchDarklyLocalStatus, false)

                            m.util.memcpy(launchDarklyLocalResponseBinary, 0, launchDarklyLocalResponseBinaryCopy, 0, launchDarklyLocalStatus)

                            m.streamHTTP.addBytes(launchDarklyLocalResponseBinaryCopy)

                            if m.runHTTPStep() = false then
                                return
                            end if
                        end if
                    end while
                end if
            end function,

            runHTTPStep: function() as Boolean
                while true
                    launchDarklyLocalChunk = m.streamHTTP.streamHTTP()

                    if m.streamHTTP.responseStatus < 0 then
                        launchDarklyLocalErrorText = m.streamCrypto.responseStatusText()
                        m.config.private.logger.error("http stream: " + launchDarklyLocalErrorText)
                        m.killStream()

                        return false
                    else if m.streamHTTP.responseStatus >= 1 AND m.stage = m.stageMap.readingHeader then
                        launchDarklyLocalCode = m.streamHTTP.responseCode

                        m.config.private.logger.debug("stream response code: " + launchDarklyLocalCode.toStr())

                        if launchDarklyLocalCode = 401 OR launchDarklyLocalCode = 403 then
                            m.config.private.logger.error("streaming not authorized")

                            m.killStream()
                            m.status.private.setStatus(m.status.map.unauthorized)

                            return false
                        else if launchDarklyLocalCode < 200 OR launchDarklyLocalCode >= 300 then
                            m.config.private.logger.warn("stream http request fail")

                            m.killStream()

                            return false
                        end if

                        m.stage = m.stageMap.readingBody
                    end if

                    if launchDarklyLocalChunk = invalid then
                        m.config.private.logger.debug("http stream no chunk")
                        return true
                    else
                        m.config.private.logger.debug("http stream got chunk")
                        m.streamCrypto.addBytes(launchDarklyLocalChunk)

                        if m.runCryptoStep() = false then
                            return false
                        end if
                    end if
                end while
            end function,

            runCryptoStep: function() as Boolean
                while true
                    launchDarklyLocalPlainText = m.streamCrypto.consumeEvent()

                    if m.streamCrypto.getErrorCode() <> 0 then
                        launchDarklyLocalErrorText = m.streamCrypto.getErrorString()
                        m.config.private.logger.error("crypto stream error: " + launchDarklyLocalErrorText)
                        m.killStream()

                        return false
                    end if

                    if launchDarklyLocalPlainText = invalid then
                        m.config.private.logger.debug("crypto stream no plaintext")
                        return true
                    else
                        m.config.private.logger.debug("crypto stream got plaintext")

                        m.streamSSE.addChunk(launchDarklyLocalPlainText.toAsciiString())

                        if m.runSSEStep() = false then
                            return false
                        end if
                    end if
                end while
            end function

            runSSEStep: function() as Boolean
                while true
                    launchDarklyLocalEvent = m.streamSSE.consumeEvent()

                    if launchDarklyLocalEvent = invalid then
                        m.config.private.logger.debug("SSE stream no event")
                        return true
                    else
                        m.config.private.logger.debug("SSE stream got event: " + launchDarklyLocalEvent.name)

                        launchDarklyLocalBody = parseJSON(launchDarklyLocalEvent.value)

                        if launchDarklyLocalBody = invalid then
                            m.config.private.logger.error("SSE stream failed to parse JSON")
                            m.killStream()
                            return false
                        end if

                        m.streamBackoff.gotStreamData()

                        if launchDarklyLocalEvent.name = "put" then
                            m.store.putAll(launchDarklyLocalBody)
                            m.status.private.setStatus(m.status.map.initialized)
                        else if launchDarklyLocalEvent.name = "patch" then
                            if getInterface(launchDarklyLocalBody.key, "ifString") = invalid then
                                m.config.private.logger.error("SSE stream patch body invalid key")
                            else
                                m.store.upsert(launchDarklyLocalBody)
                            end if
                        else if launchDarklyLocalEvent.name = "delete" then
                            m.store.delete(launchDarklyLocalBody["key"], launchDarklyLocalBody["version"])
                        end if
                    end if
                end while
            end function

            handleStreamMessage: function(launchDarklyParamMessage as Dynamic) as Void
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

                            launchDarklyLocalStatus = m.streamSocket.send(m.streamRequestContent, m.streamRequestSent, m.streamRequestContent.count() - m.streamRequestSent)

                            if launchDarklyLocalStatus = -1 then
                                m.config.private.logger.debug("socket must wait to write")
                                exit while
                            else if launchDarklyLocalStatus = 0 then
                                m.config.private.logger.debug("socket closed")
                                m.killStream()
                                return
                            else if launchDarklyLocalStatus > 0 then
                                m.config.private.logger.debug("socket sent bytes " + launchDarklyLocalStatus.toStr())

                                m.streamTCPTimer.mark()

                                m.streamRequestSent += launchDarklyLocalStatus
                            end if
                        end while
                    end if
                end if

                if m.stage = m.stageMap.readingHeader OR m.stage = m.stageMap.readingBody then
                    m.runTCPStep()
                end if
            end function,

            handleHandshakeMessage: function(launchDarklyParamMessage as Dynamic) as Void
                launchDarklyLocalResponseCode = launchDarklyParamMessage.getResponseCode()

                m.config.private.logger.debug("handshake response code: " + launchDarklyLocalResponseCode.toStr())

                if launchDarklyLocalResponseCode = 401 OR launchDarklyLocalResponseCode = 403 then
                    m.config.private.logger.error("streaming handshake not authorized")

                    m.status.private.setStatus(m.status.map.unauthorized)

                    return
                else if launchDarklyLocalResponseCode = 404 then
                    m.config.private.logger.error("handshake endpoint not found switching to polling")

                    m.config.private.streaming = false

                    return
                else if launchDarklyLocalResponseCode < 200 OR launchDarklyLocalResponseCode >= 300 then
                    m.config.private.logger.error("streaming handshake not successful")

                    m.killStream()

                    return
                end if

                launchDarklyLocalDecoded = parseJSON(launchDarklyParamMessage.getString())

                if launchDarklyLocalDecoded = invalid then
                    m.config.private.logger.error("failed json decoding")

                    m.killStream()

                    return
                end if

                m.config.private.logger.debug("got shared secret")

                launchDarklyLocalCipherKeyBuffer = launchDarklyLocalDecoded.cipherKey
                launchDarklyLocalAuthKeyBuffer = launchDarklyLocalDecoded.authenticationKey

                launchDarklyLocalCipherKey = createObject("roByteArray")
                launchDarklyLocalCipherKey.fromBase64String(launchDarklyLocalDecoded.cipherKey)

                launchDarklyLocalAuthKey = createObject("roByteArray")
                launchDarklyLocalAuthKey.fromBase64String(launchDarklyLocalDecoded.authenticationKey)

                launchDarklyLocalBundle = createObject("roByteArray")
                launchdarklyLocalBundle.fromBase64String(launchDarklyLocalDecoded.serverBundle)

                uriParts = m.util.extractUriParts(m.config.private.streamURI)
                path = uriParts["path"] + "/mevalalternate"
                launchDarklyLocalHostname = m.util.stripHTTPProtocol(m.config.private.streamURI)

                launchDarklyLocalRequestText = ""
                launchDarklyLocalRequestText += "POST " + path + " HTTP/1.1" + chr(13) + chr(10)
                launchDarklyLocalRequestText += "User-Agent: RokuClient/" + LaunchDarklySDKVersion() + chr(13) + chr(10)
                launchDarklyLocalRequestText += "Content-Length: " + launchDarklyLocalBundle.count().toStr() + chr(13) + chr(10)
                launchDarklyLocalRequestText += "Host: " + uriParts["host"] + chr(13) + chr(10)

                appInfoHeader = m.util.createApplicationInfoHeader(m.config)
                if appInfoHeader <> "" then
                  launchDarklyLocalRequestText += "X-LaunchDarkly-Tags: " + appInfoHeader + chr(13) + chr(10)
                end if

                launchDarklyLocalRequestText += "X-LaunchDarkly-AltStream-Version: 2" + chr(13) + chr(10)
                launchDarklyLocalRequestText += "Connection: close" + chr(13) + chr(10)
                launchDarklyLocalRequestText += chr(13) + chr(10)

                if m.config.private.forcePlainTextInStream then
                  m.streamCrypto = LaunchDarklyPlainTextReader(launchDarklyLocalCipherKey, launchDarklyLocalAuthKey)
                else
                  m.streamCrypto = LaunchDarklyCryptoReader(launchDarklyLocalCipherKey, launchDarklyLocalAuthKey)
                end if

                m.streamRequestContent = createObject("roByteArray")
                m.streamRequestContent.fromAsciiString(launchDarklyLocalRequestText)
                m.streamRequestContent.append(launchDarklyLocalBundle)

                launchDarklyLocalSendAddress = createObject("roSocketAddress")
                launchDarklyLocalSendAddress.setHostname(uriParts["host"])

                ' By default we should be connecting on port 80 since this
                ' doesn't support TLS. However, for the SDK test harness, we
                ' might need to use alternative ports if specified as part of
                ' the URL.
                if uriParts["port"] = invalid then
                  launchDarklyLocalSendAddress.setPort(80)
                else
                  launchDarklyLocalSendAddress.setPort(uriParts["port"])
                end if

                launchDarklyLocalSocket = createObject("roStreamSocket")
                launchDarklyLocalSocket.setSendToAddress(launchDarklyLocalSendAddress)
                launchDarklyLocalSocket.setMessagePort(m.messagePort)
                launchDarklyLocalSocket.notifyReadable(true)
                launchDarklyLocalSocket.notifyWritable(true)
                launchDarklyLocalSocket.setKeepAlive(true)

                m.streamSocket = launchDarklyLocalSocket
                m.streamHTTP = LaunchDarklyHTTPResponse()
                m.streamSSE = LaunchDarklySSE()
                m.streamRequestSent = 0
                m.streamTCPTimer.mark()

                if launchDarklyLocalSocket.connect() then
                    m.config.private.logger.debug("streaming socket connection success")
                    m.stage = m.stageMap.sendingRequest
                else
                    m.config.private.logger.error("streaming socket connection failure")
                    m.killStream()
                end if
            end function,
        },

        handleMessage: function(launchDarklyParamMessage=invalid as Dynamic) as Boolean
            if m.private.config.private.streaming = false then
                return false
            end if

            if m.private.streamTCPTimer.totalSeconds() > 60 * 5 then
                m.private.killStream()
            end if

            REM start stream if it is not active
            if m.private.status.getStatus() <> m.private.status.map.unauthorized AND m.private.config.private.streaming AND m.private.stage = m.private.stageMap.notStarted then
                if m.private.streamBackoff.shouldWait() = false then
                    m.private.config.private.logger.debug("streaming timeout hit")

                    m.private.startHandshakeTransfer()
                else
                    m.private.config.private.logger.debug("waiting on stream retry")
                end if
            end if

            if type(launchDarklyParamMessage) = "roUrlEvent" then
                launchDarklyLocalEventId = launchDarklyParamMessage.getSourceIdentity()
                launchDarklyLocalHandshakeId = m.private.handshakeTransfer.getIdentity()

                if launchDarklyLocalEventId = launchDarklyLocalHandshakeId then
                    m.private.handleHandshakeMessage(launchDarklyParamMessage)

                    return true
                end if
            else if type(launchDarklyParamMessage) = "roSocketEvent" then
                if m.private.streamSocket <> invalid AND launchDarklyParamMessage.getSocketID() = m.private.streamSocket.getID() then
                    m.private.handleStreamMessage(launchDarklyParamMessage)

                    return true
                end if
            end if

            return false
        end function,

        changeContext: function(context as Object)
            m.private.config.private.logger.debug("stream client switching context")

            m.private.context = context
            m.private.killStream()
            m.private.streamBackoff.reset()
            m.handleMessage(invalid)
        end function
    }

    launchDarklyLocalThis.private.prepareHandshakeTransfer()
    launchDarklyLocalThis.handleMessage(invalid)

    return launchDarklyLocalThis
end function
