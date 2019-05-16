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

            eventsTransfer: createObject("roUrlTransfer"),
            events: createObject("roArray", 0, true),
            eventsFlushTimer: createObject("roTimeSpan"),
            eventsFlushActive: false,

            handlePollingMessage: function(message as Dynamic) as Void
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
                    m.stopPolling()
                end if
            end function,

            handleEventMessage: function(message as Dynamic) as Void
                responseCode = message.getResponseCode()

                print responseCode

                if responseCode = 200 then
                    print "events sent"
                end if

                if responseCode = 401 OR responseCode = 403 then
                    print "not authorized"
                else
                    m.stopPolling()
                end if
            end function,

            getMilliseconds: function()
                REM Clock is stopped on object creation
                now = CreateObject("roDateTime")
                REM Ensure 64 bit number is used
                creationDate& = now.asSeconds()
                creationDate& *= 1000
                creationDate& += now.getMilliseconds()
                return creationDate&
            end function,

            makeBaseEvent: function(kind as String) as Object
                return {
                    kind: kind,
                    user: m.user.private.encode(true, m.config),
                    creationDate: m.getMilliseconds()
                }
            end function,

            makeFeatureEvent: function(value as Dynamic, fallback as Dynamic) as Object
                event = m.makeBaseEvent("feature")

                if flag.lookup("flagVersion") <> invalid then
                    event.version = flag.flagVersion
                else
                    event.version = flag.version
                end if

                event.variation = flag.variation
                event.value = flag.value
                event.default = fallback

                return event
            end function,

            enqueueEvent: function(event as Object) as Void
                if m.events.count() < m.config.private.eventsCapacity then
                    m.events.push(event)
                else
                    print "eventsCapacity exceeded dropping event"
                end if
            end function,

            prepareNetworkingCommon: function(transfer as Object) as Void
                transfer.setPort(m.messagePort)
                transfer.addHeader("Authorization", m.config.private.mobileKey)
                transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
                transfer.InitClientCertificates()
            end function,

            preparePolling: function() as Void
                buffer = createObject("roByteArray")
                buffer.fromAsciiString(FormatJSON(m.user.private.encode(false)))
                userBase64JSON = buffer.toBase64String()
                url = m.config.private.appURI + "/msdk/evalx/users/" + userBase64JSON
                print url

                m.prepareNetworkingCommon(m.pollingTransfer)
                m.pollingTransfer.setURL(url)
            end function,

            prepareEventTransfer: function() as Void
                url = m.config.private.eventsURI + "/mobile"
                print url

                m.prepareNetworkingCommon(m.eventsTransfer)
                m.eventsTransfer.addHeader("Content-Type", "application/json")
                m.eventsTransfer.addHeader("X-LaunchDarkly-Event-Schema", "3")
                m.eventsTransfer.setURL(url)
            end function

            startPolling: function() as Void
                if m.config.private.offline = false then
                    m.pollingActive = true
                    m.pollingTransfer.asyncGetToString()
                end if
            end function,

            stopPolling: function() as Void
                m.pollingTimer.mark()
                m.pollingActive = false
                m.pollingTransfer.asyncCancel()
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

                    now = m.private.getMilliseconds()

                    if flag.track <> invalid AND flag.track > 0 AND flag.track > now then
                        event = m.private.makeFeatureEvent(flag, fallback)

                        m.private.enqueueEvent(event)
                    end if

                    return flag.value
                end if
            end if
        end function,

        track: function(key as String, data=invalid as Object) as Void
            event = m.private.makeBaseEvent("track")
            event.key = key

            if data <> invalid then
                event.data = data
            end if

            m.private.enqueueEvent(event)
        end function,

        flush: function() as Void
            if m.private.config.private.offline = false then
                if m.private.eventsFlushActive = false then
                    m.private.eventsFlushActive = true
                    serialized = FormatJSON(m.private.events)
                    m.private.events.clear()
                    m.private.eventsTransfer.asyncPostFromString(serialized)
                end if
            end if
        end function,

        identify: function(user as Object) as Void
            m.private.user = user
            event = m.private.makeBaseEvent("identify")
            m.private.enqueueEvent(event)
            m.private.stopPolling()
            m.private.preparePolling()
            m.private.startPolling()
        end function,

        handleMessage: function(message as Dynamic) as Boolean
            if type(message) = "roUrlEvent" then
                eventId = message.getSourceIdentity()
                pollingId = m.private.pollingTransfer.getIdentity()
                eventsId = m.private.eventsTransfer.getIdentity()

                if eventId = pollingId then
                    m.private.handlePollingMessage(message)

                    return true
                else if eventId = eventsId then
                    m.private.handleEventsMessage(message)

                    return true
                end if
            end if

            if m.private.pollingActive = false then
                elapsed = m.private.pollingTimer.totalSeconds()

                if elapsed >= m.private.config.private.pollingInterval then
                    print "polling timeout hit"

                    m.private.startPolling()
                end if
            end if

            if m.private.eventsFlushActive = false then
                elapsed = m.private.eventsFlushTimer.totalSeconds()

                if elapsed >= m.private.config.private.eventsFlushInterval then
                    print "flush timeout hit"

                    m.flush()
                end if
            end if

            return false
        end function
    }

    this.private.prepareEventTransfer()
    this.private.preparePolling()
    this.private.startPolling()

    return this
end function
