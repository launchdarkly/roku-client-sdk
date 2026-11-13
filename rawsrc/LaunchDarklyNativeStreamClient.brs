' Roku OS 16 adds Server-Sent Events support to roUrlTransfer. This function
' returns true when the device has that support.
function LaunchDarklyNativeStreamSupported() as Boolean
    return FindMemberFunction(createObject("roUrlTransfer"), "AsyncGetSSEvents") <> invalid
end function

' Returns true when the client must use the native stream client. The
' application can turn off the native client in the config.
function LaunchDarklyUseNativeStream(config as Object) as Boolean
    return config.private.useNativeStream AND LaunchDarklyNativeStreamSupported()
end function

' Returns true when the stream must retry after this HTTP status. The SDK
' retries after 400, 408, 429 and all 5xx errors. All other 4xx errors stop
' the stream.
function LaunchDarklyIsRecoverableStreamStatus(code as Integer) as Boolean
    if code >= 400 AND code < 500 then
        return code = 400 OR code = 408 OR code = 429
    end if

    return true
end function

function LaunchDarklyIsInteger(value as Dynamic) as Boolean
    return getInterface(value, "ifInt") <> invalid
end function

' Applies one stream event to the store. It returns false when the event data
' is not valid. The caller must then close the stream. Events other than put,
' patch and delete are ignored.
function LaunchDarklyApplyStreamEvent(config as Object, store as Object, status as Object, name as String, data as String) as Boolean
    if name <> "put" AND name <> "patch" AND name <> "delete" then
        config.private.logger.debug("SSE stream ignored event: " + name)
        return true
    end if

    body = parseJSON(data)

    if getInterface(body, "ifAssociativeArray") = invalid then
        config.private.logger.error("SSE stream " + name + " data is not a JSON object")
        return false
    end if

    if name = "put" then
        for each key in body
            flag = body[key]

            if getInterface(flag, "ifAssociativeArray") = invalid OR LaunchDarklyIsInteger(flag.version) = false then
                config.private.logger.error("SSE stream put has an invalid flag: " + key)
                return false
            end if
        end for

        store.putAll(body)
        status.private.setStatus(status.map.initialized)

        return true
    end if

    if getInterface(body.key, "ifString") = invalid OR LaunchDarklyIsInteger(body.version) = false then
        config.private.logger.error("SSE stream " + name + " data has an invalid key or version")
        return false
    end if

    if name = "patch" then
        store.upsert(body)
    else
        store.delete(body.key, body.version)
    end if

    return true
end function

' This stream client reads the standard client-side stream over HTTPS. Use it
' only when LaunchDarklyUseNativeStream returns true.
'
' The client cannot detect a connection that stops without a close, because
' Roku does not deliver SSE comments. Thus the client reconnects when the
' device network connection comes back.
function LaunchDarklyNativeStreamClient(config as Object, store as Object, messagePort as Object, context as Object, status as Object) as Object
    this = {
        private: {
            config: config,
            store: store,
            messagePort: messagePort,
            context: context,
            status: status,
            util: LaunchDarklyUtility(),

            transfer: invalid,
            streamBackoff: LaunchDarklyBackoff(),

            ' This is true after an unrecoverable error. The stream then
            ' stays closed until the context changes.
            halted: false,

            deviceInfo: invalid,
            linkUp: true,
            internetUp: true,

            streamURL: function() as String
                encoded = createObject("roByteArray")
                encoded.fromAsciiString(FormatJSON(NewLaunchDarklyContextFilter().filter(m.context, true)))

                ' The context goes in the URL path, so use the URL-safe base64 alphabet.
                contextBase64 = encoded.toBase64String().replace("+", "-").replace("/", "_")

                url = m.config.private.streamURI + "/meval/" + contextBase64

                if m.config.private.useReasons then
                    url += "?withReasons=true"
                end if

                return url
            end function,

            canStream: function() as Boolean
                return m.config.private.streaming AND m.halted = false AND m.status.getStatus() <> m.status.map.unauthorized
            end function,

            startStream: function() as Void
                if m.config.private.offline then
                    return
                end if

                url = m.streamURL()
                m.config.private.logger.debug("native stream url: " + url)

                ' Each stream attempt uses a new transfer. Events from an earlier
                ' transfer then have a different source identity and are ignored.
                m.transfer = createObject("roUrlTransfer")
                m.util.prepareNetworkingCommon(m.messagePort, m.config, m.transfer, {})
                m.transfer.setURL(url)

                m.streamBackoff.started()

                if m.transfer.asyncGetSSEvents() = false then
                    m.config.private.logger.error("native stream failed to start")
                    m.killStream()
                end if
            end function,

            cancelTransfer: function() as Void
                if m.transfer <> invalid then
                    m.transfer.asyncCancel()
                    m.transfer = invalid
                end if
            end function,

            ' Closes the stream and starts the backoff before the next attempt.
            killStream: function() as Void
                m.cancelTransfer()
                m.streamBackoff.finished()
            end function,

            ' Closes the stream and does not retry.
            haltStream: function() as Void
                m.cancelTransfer()
                m.halted = true
            end function,

            ' Opens a new stream at once, without a backoff.
            reconnectNow: function() as Void
                if m.canStream() = false then
                    return
                end if

                m.config.private.logger.debug("native stream reconnecting after network change")

                m.cancelTransfer()
                m.streamBackoff.reset()
                m.startStream()
            end function,

            watchNetwork: function(deviceInfo as Object) as Void
                m.deviceInfo = deviceInfo
                m.deviceInfo.setMessagePort(m.messagePort)
                m.deviceInfo.enableLinkStatusEvent(true)
                m.deviceInfo.enableInternetStatusEvent(true)
                m.linkUp = m.deviceInfo.getLinkStatus()
                m.internetUp = m.deviceInfo.getInternetStatus()
            end function,

            handleNetworkMessage: function(message as Object) as Void
                if message.isStatusMessage() = false then
                    return
                end if

                info = message.getInfo()
                wasUp = m.linkUp AND m.internetUp

                if getInterface(info.linkStatus, "ifBoolean") <> invalid then
                    m.linkUp = info.linkStatus
                end if

                if getInterface(info.internetStatus, "ifBoolean") <> invalid then
                    m.internetUp = info.internetStatus
                end if

                isUp = m.linkUp AND m.internetUp

                m.config.private.logger.debug("native stream network up: " + isUp.toStr())

                ' The old connection can be dead without an error. Replace it.
                if isUp AND wasUp = false then
                    m.reconnectNow()
                end if
            end function,

            isFromTransfer: function(message as Dynamic) as Boolean
                return m.transfer <> invalid AND message.getSourceIdentity() = m.transfer.getIdentity()
            end function,

            handleTransferMessage: function(message as Object) as Void
                code = message.getResponseCode()
                kind = message.getInt()

                if kind <> 1 AND kind <> 2 then
                    return
                end if

                if code >= 200 AND code < 300 then
                    if kind = 2 then
                        m.config.private.logger.debug("native stream connected")
                    else
                        m.config.private.logger.debug("native stream closed by the server")
                        m.killStream()
                    end if

                    return
                end if

                m.config.private.logger.debug("native stream failed with code: " + code.toStr() + " reason: " + message.getFailureReason())

                if code = 401 OR code = 403 then
                    m.config.private.logger.error("streaming not authorized")

                    m.haltStream()
                    m.status.private.setStatus(m.status.map.unauthorized)
                else if code > 0 AND LaunchDarklyIsRecoverableStreamStatus(code) = false then
                    m.config.private.logger.error("streaming stopped after unrecoverable HTTP error " + code.toStr())

                    m.haltStream()
                else
                    m.config.private.logger.warn("stream connection failed, will retry")

                    m.killStream()
                end if
            end function,

            handleStreamEvent: function(message as Object) as Void
                name = message.getEvent()

                m.config.private.logger.debug("SSE stream got event: " + name)

                if LaunchDarklyApplyStreamEvent(m.config, m.store, m.status, name, message.getData()) then
                    m.streamBackoff.gotStreamData()
                else
                    m.killStream()
                end if
            end function
        },

        handleMessage: function(message = invalid as Dynamic) as Boolean
            if m.private.config.private.streaming = false then
                return false
            end if

            if type(message) = "roDeviceInfoEvent" then
                ' The application can have its own roDeviceInfo on this port.
                ' Do not consume the event.
                m.private.handleNetworkMessage(message)
            end if

            if m.private.canStream() AND m.private.transfer = invalid then
                if m.private.streamBackoff.shouldWait() = false then
                    m.private.config.private.logger.debug("streaming timeout hit")

                    m.private.startStream()
                else
                    m.private.config.private.logger.debug("waiting on stream retry")
                end if
            end if

            if type(message) = "roSSEvent" AND m.private.isFromTransfer(message) then
                m.private.handleStreamEvent(message)

                return true
            else if type(message) = "roUrlEvent" AND m.private.isFromTransfer(message) then
                m.private.handleTransferMessage(message)

                return true
            end if

            return false
        end function,

        changeContext: function(context as Object)
            m.private.config.private.logger.debug("stream client switching context")

            m.private.context = context
            m.private.halted = false
            m.private.killStream()
            m.private.streamBackoff.reset()
            m.handleMessage(invalid)
        end function
    }

    if config.private.streaming then
        this.private.watchNetwork(createObject("roDeviceInfo"))
    end if

    this.handleMessage(invalid)

    return this
end function
