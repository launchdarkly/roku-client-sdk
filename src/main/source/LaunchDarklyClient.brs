function LaunchDarklyClient(config as Object, user as Object, messagePort as Object) as Object
    this = {
        private: {
            user: user,
            config: config,
            messagePort: messagePort,
            store: {},

            pollingTransfer: createObject("roUrlTransfer"),
            pollingTimer: createObject("roTimeSpan"),
            pollingActive: false,

            events: createObject("roArray", 0, true),

            handlePolling: function(message as Dynamic) as Void
                responseCode = message.getResponseCode()

                print responseCode

                if responseCode = 200 then
                    decoded = ParseJSON(message.getString())

                    if decoded = invalid then
                        print "failed json decoding"
                    else
                        print "updating store"
                        m.store = decoded
                    end if
                end if

                if responseCode = 401 OR responseCode = 403 then
                    print "not authorized"
                else
                    m.pollingTimer.mark()
                    m.pollingActive = false
                end if
            end function,

            makeBaseEvent: function(kind as String) as Object
                return {
                    kind: kind,
                    user: m.user.private.encode(true, m.config),
                    creationDate: 0
                }
            end function,

            enqueueEvent: function(event as Object) as Void
                if m.events.count() < m.config.private.eventsCapacity then
                    m.events.push(event)
                else
                    print "eventsCapacity exceeded dropping event"
                end if
            end function
        },

        variation: function(flagKey as String, fallback as Dynamic) as Dynamic
            if m.private.config.private.offline then
                return fallback
            else
                flag = m.private.store.lookup(flagKey)

                if flag = invalid then
                    print "missing flag"

                    return fallback
                else
                    print "found flag"

                    return flag.value
                end if
            end if
        end function,

        track: function(key as String, data=invalid as Object) as Void
            event = m.private.makeBaseEvent("identify")
            event.key = key

            if data <> invalid then
                event.data = data
            end if

            m.private.enqueueEvent(event)
        end function,

        handleMessage: function(message as Dynamic) as Boolean
            if type(message) = "roUrlEvent" then
                eventId = message.getSourceIdentity()
                pollingId = m.private.pollingTransfer.getIdentity()

                if eventId = pollingId then
                    m.private.handlePolling(message)

                    return true
                end if
            end if

            if m.private.pollingActive = false then
                elapsed = m.private.pollingTimer.totalSeconds()

                if elapsed >= m.private.config.private.pollingInterval then
                    print "timeout hit"

                    m.private.pollingTransfer.asyncGetToString()
                    m.private.pollingActive = true
                end if
            end if

            return false
        end function
    }

    buffer = createObject("roByteArray")
    buffer.fromAsciiString(FormatJSON(user.private.encode(false)))
    userBase64JSON = buffer.toBase64String()
    url = config.private.appURI + "/msdk/evalx/users/" + userBase64JSON
    print url

    this.private.pollingTransfer.setPort(messagePort)
    this.private.pollingTransfer.setURL(url)
    this.private.pollingTransfer.addHeader("Authorization", config.private.mobileKey)
    this.private.pollingTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    this.private.pollingTransfer.InitClientCertificates()

    if config.private.offline = false then
        this.private.pollingActive = true
        this.private.pollingTransfer.asyncGetToString()
    end if

    return this
end function
