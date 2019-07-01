function LaunchDarklyClient(config as Object, user as Object, messagePort as Object) as Object
    store = LaunchDarklyStore(config.private.storeBackend)

    this = {
        private: {
            user: user,
            encodedUser: user.private.encode(true, config),

            config: config,
            messagePort: messagePort,
            store: store,

            unauthorized: false,

            pollingInitial: true,
            pollingTransfer: createObject("roUrlTransfer"),
            pollingTimer: createObject("roTimeSpan"),
            pollingActive: false,

            eventsTransfer: createObject("roUrlTransfer"),
            events: createObject("roArray", 0, true),
            eventsFlushTimer: createObject("roTimeSpan"),
            eventsFlushActive: false,
            eventsSummary: {},
            eventsSummaryStart: 0,

            streamClient: LaunchDarklyStreamClient(config, store, messagePort, user),

            util: LaunchDarklyUtility(),

            handlePollingMessage: function(message as Dynamic) as Void
                responseCode = message.getResponseCode()

                m.config.private.logger.debug("polling response code: " + responseCode.toStr())

                if responseCode >= 200 AND responseCode < 300 then
                    decoded = ParseJSON(message.getString())

                    if decoded = invalid then
                        m.config.private.logger.error("failed json decoding")
                    else
                        m.config.private.logger.debug("updating store")

                        m.store.putAll(decoded)
                    end if
                end if

                if responseCode = 401 OR responseCode = 403 then
                    m.config.private.logger.error("polling not authorized")

                    m.unauthorized = true
                else
                    m.resetPollingTransfer()
                end if
            end function,

            handleEventsMessage: function(message as Dynamic) as Void
                responseCode = message.getResponseCode()

                m.config.private.logger.debug("events response code: " + responseCode.toStr())

                if responseCode >= 200 AND responseCode < 300 then
                    m.config.private.logger.debug("events sent")
                end if

                if responseCode = 401 OR responseCode = 403 then
                    m.config.private.logger.error("events not authorized")

                    m.unauthorized = true
                else
                    m.resetEventsTransfer()
                end if
            end function,

            getFlagVersion: function(flag as Object) as Integer
                if flag.flagVersion <> invalid then
                    return flag.flagVersion
                else
                    return flag.version
                end if
            end function,

            makeBaseEvent: function(kind as String) as Object
                return {
                    kind: kind,
                    user: m.encodedUser,
                    creationDate: m.util.getMilliseconds()
                }
            end function,

            makeFeatureEvent: function(flag as Object, fallback as Dynamic) as Object
                event = m.makeBaseEvent("feature")

                event.version = m.getFlagVersion(flag)
                event.variation = flag.variation
                event.value = flag.value
                event.default = fallback

                return event
            end function,

            makeSummaryEvent: function() as Object
                event = m.makeBaseEvent("summary")
                event.startDate = m.eventsSummaryStart
                event.endDate = m.util.getMilliseconds()
                event.features = {}

                for each featureKey in m.eventsSummary
                    feature = m.eventsSummary.lookup(featureKey)

                    featureNode = {
                        default: feature.default,
                        counters: createObject("roArray", 0, true)
                    }

                    for each counterKey in feature.counters
                        counter = feature.counters.lookup(counterKey)

                        counterNode = {
                            count: counter.count,
                            value: counter.value
                        }

                        if counter.version <> invalid then
                            counterNode.version = counter.version
                        end if

                        if counter.variation <> invalid then
                            counterNode.variation = counter.variation
                        end if

                        if counterKey = "unknown" then
                            counterNode.unknown = true
                        end if

                        featureNode.counters.push(counterNode)
                    end for

                    event.features.addReplace(featureKey, featureNode)
                end for

                return event
            end function,

            summarizeEval: function(value as Dynamic, flagKey as String, flag as Object, fallback as Dynamic, typeMatch as Boolean) as Void
                summary = m.eventsSummary.lookup(flagKey)

                if summary = invalid then
                    summary = {}
                    m.eventsSummary.addReplace(flagKey, summary)
                    summary.default = fallback
                    summary.counters = {}
                end if

                if m.eventsSummaryStart = 0 then
                    m.eventsSummaryStart = m.util.getMilliseconds()
                end if

                counterKey = invalid

                if flag = invalid then
                    counterKey = "unknown"
                else if typeMatch = false then
                    counterKey = "default"
                else
                    counterKey = m.getFlagVersion(flag).toStr() + " " + flag.variation.toStr()
                end if

                counter = summary.counters.lookup(counterKey)

                if counter = invalid then
                    counter = {
                        value: value,
                        count: 0
                    }

                    summary.counters.addReplace(counterKey, counter)
                end if

                if flag <> invalid AND counter.count = 0 then
                    counter.version = m.getFlagVersion(flag)
                    counter.variation = flag.variation
                end if

                counter.count += 1
            end function,

            enqueueEvent: function(event as Object) as Void
                if m.events.count() < m.config.private.eventsCapacity then
                    m.events.push(event)
                else
                    m.config.private.logger.warn("eventsCapacity exceeded dropping event")
                end if
            end function,

            preparePolling: function() as Void
                buffer = createObject("roByteArray")
                buffer.fromAsciiString(FormatJSON(m.user.private.encode(false)))
                userBase64JSON = buffer.toBase64String()
                url = m.config.private.appURI + "/msdk/evalx/users/" + userBase64JSON

                m.config.private.logger.debug("polling url: " + url)

                m.util.prepareNetworkingCommon(m.messagePort, m.config, m.pollingTransfer)
                m.pollingTransfer.setURL(url)
            end function,

            prepareEventTransfer: function() as Void
                url = m.config.private.eventsURI + "/mobile"

                m.config.private.logger.debug("events url: " + url)

                m.util.prepareNetworkingCommon(m.messagePort, m.config, m.eventsTransfer)
                m.eventsTransfer.addHeader("Content-Type", "application/json")
                m.eventsTransfer.addHeader("X-LaunchDarkly-Event-Schema", "3")
                m.eventsTransfer.setURL(url)
            end function

            startPollingTransfer: function() as Void
                m.pollingActive = true
                m.pollingTransfer.asyncGetToString()
                m.pollingInitial = false
            end function,

            resetPollingTransfer: function() as Void
                m.pollingTimer.mark()
                m.pollingActive = false
                m.pollingTransfer.asyncCancel()
            end function,

            resetEventsTransfer: function() as Void
                m.eventsFlushTimer.mark()
                m.eventsFlushActive = false
                m.eventsTransfer.asyncCancel()
            end function
        },

        variation: function(flagKey as String, fallback as Dynamic, strong=invalid as Dynamic) as Dynamic
            if m.private.config.private.offline then
                return fallback
            else
                flag = m.private.store.get(flagKey)

                if flag = invalid then
                    m.private.config.private.logger.error("missing flag")

                    m.private.summarizeEval(fallback, flagKey, invalid, fallback, true)

                    return fallback
                else
                    now = m.private.util.getMilliseconds()

                    typeMatch = true
                    if strong <> invalid then
                        if getInterface(flag.value, strong) = invalid then
                            m.private.config.private.logger.error("eval type mismatch")

                            typeMatch = false
                        end if
                    end if

                    shouldTrack = flag.trackEvents <> invalid AND flag.trackEvents = true
                    shouldDebug = flag.debugEventsUntilDate <> invalid AND flag.debugEventsUntilDate > now

                    if shouldTrack OR shouldDebug then
                       event = m.private.makeFeatureEvent(flag, fallback)

                       m.private.enqueueEvent(event)
                    end if

                    value = invalid
                    if typeMatch = true then
                        value = flag.value
                    else
                        value = fallback
                    end if

                    m.private.summarizeEval(value, flagKey, flag, fallback, typeMatch)

                    return value
                end if
            end if
        end function,

        intVariation: function(flagKey as String, fallback as Integer) as Integer
            return m.variation(flagKey, fallback, "ifInt")
        end function,

        boolVariation: function(flagKey as String, fallback as Boolean) as Boolean
            return m.variation(flagKey, fallback, "ifBoolean")
        end function,

        stringVariation: function(flagKey as String, fallback as String) as String
            return m.variation(flagKey, fallback, "ifString")
        end function,

        aaVariation: function(flagKey as String, fallback as Object) as Object
            return m.variation(flagKey, fallback, "ifAssociativeArray")
        end function,

        track: function(key as String, data=invalid as Object) as Void
            event = m.private.makeBaseEvent("custom")
            event.key = key

            if data <> invalid then
                event.data = data
            end if

            m.private.enqueueEvent(event)
        end function,

        flush: function() as Void
            if m.private.config.private.offline = false then
                if m.private.eventsFlushActive = false then
                    if m.private.eventsSummaryStart <> 0 then
                        summary = m.private.makeSummaryEvent()
                        m.private.events.push(summary)
                        m.private.eventsSummary = {}
                        m.private.eventsSummaryStart = 0
                    end if

                    m.private.eventsFlushActive = true
                    serialized = FormatJSON(m.private.events)
                    m.private.events.clear()
                    m.private.eventsTransfer.asyncPostFromString(serialized)
                end if
            end if
        end function,

        identify: function(user as Object) as Void
            m.private.user = user
            m.private.encodedUser = m.private.user.private.encode(true, m.private.config)
            event = m.private.makeBaseEvent("identify")
            m.private.enqueueEvent(event)

            m.private.streamClient.changeUser(user)
            m.handleMessage(invalid)

            m.private.resetPollingTransfer()
            m.private.preparePolling()
        end function,

        handleMessage: function(message=invalid as Dynamic) as Boolean
            if m.private.unauthorized = false AND m.private.config.private.offline = false then
                REM start polling if timeout is hit
                if m.private.config.private.streaming = false AND m.private.pollingActive = false then
                    elapsed = m.private.pollingTimer.totalSeconds()

                    if m.private.pollingInitial OR elapsed >= m.private.config.private.pollingIntervalSeconds then
                        m.private.config.private.logger.debug("polling timeout hit")

                        m.private.startPollingTransfer()
                    end if
                end if

                REM flush events if timeout is hit
                if m.private.eventsFlushActive = false then
                    elapsed = m.private.eventsFlushTimer.totalSeconds()

                    if elapsed >= m.private.config.private.eventsFlushIntervalSeconds then
                        m.private.config.private.logger.debug("flush timeout hit")

                        m.flush()
                    end if
                end if
            end if

            if m.private.streamClient.handleMessage(message) then
                return true
            else if type(message) = "roUrlEvent" then
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

            return false
        end function
    }

    this.private.prepareEventTransfer()
    this.private.preparePolling()

    this.handleMessage(invalid)

    return this
end function
