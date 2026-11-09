' Roku OS 16 adds Server-Sent Events support to roUrlTransfer. This function
' returns true when the device has that support.
function LaunchDarklyNativeStreamSupported() as Boolean
    return FindMemberFunction(createObject("roUrlTransfer"), "AsyncGetSSEvents") <> invalid
end function

' Applies one stream event to the store. It returns false when the event data
' is not valid JSON. The caller must then close the stream.
function LaunchDarklyApplyStreamEvent(config as Object, store as Object, status as Object, name as String, data as String) as Boolean
    body = parseJSON(data)

    if body = invalid then
        config.private.logger.error("SSE stream failed to parse JSON")
        return false
    end if

    if name = "put" then
        store.putAll(body)
        status.private.setStatus(status.map.initialized)
    else if name = "patch" then
        if getInterface(body.key, "ifString") = invalid then
            config.private.logger.error("SSE stream patch body invalid key")
        else
            store.upsert(body)
        end if
    else if name = "delete" then
        store.delete(body["key"], body["version"])
    end if

    return true
end function

' This stream client reads the standard client-side stream over HTTPS. Use it
' only when LaunchDarklyNativeStreamSupported returns true.
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

            killStream: function() as Void
                if m.transfer <> invalid then
                    m.transfer.asyncCancel()
                    m.transfer = invalid
                end if

                m.streamBackoff.finished()
            end function,

            isFromTransfer: function(message as Dynamic) as Boolean
                return m.transfer <> invalid AND message.getSourceIdentity() = m.transfer.getIdentity()
            end function,

            handleTransferMessage: function(message as Object) as Void
                code = message.getResponseCode()

                if message.getInt() = 2 then
                    m.config.private.logger.debug("native stream response code: " + code.toStr())
                else if message.getInt() = 1 then
                    m.config.private.logger.debug("native stream ended with code: " + code.toStr() + " reason: " + message.getFailureReason())
                else
                    return
                end if

                if code = 401 OR code = 403 then
                    m.config.private.logger.error("streaming not authorized")

                    m.killStream()
                    m.status.private.setStatus(m.status.map.unauthorized)
                else if code < 200 OR code >= 300 then
                    m.config.private.logger.warn("stream http request fail")

                    m.killStream()
                else if message.getInt() = 1 then
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

            if m.private.status.getStatus() <> m.private.status.map.unauthorized AND m.private.transfer = invalid then
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
            m.private.killStream()
            m.private.streamBackoff.reset()
            m.handleMessage(invalid)
        end function
    }

    this.handleMessage(invalid)

    return this
end function
