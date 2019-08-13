function LaunchDarklyClientSharedFunctions() as Object
    return {
        variation: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Dynamic, launchDarklyParamStrong=invalid as Dynamic) as Dynamic
            if m.private.isOffline() then
                return launchDarklyParamFallback
            else
                launchDarklyLocalFlag = m.private.lookupFlag(launchDarklyParamFlagKey)

                if launchDarklyLocalFlag = invalid then
                    m.private.logger.error("missing flag")

                    launchDarklyLocalState = {
                        value: launchDarklyParamFallback,
                        flagKey: launchDarklyParamFlagKey,
                        flag: invalid,
                        fallback: launchDarklyParamFallback,
                        typeMatch: true
                    }

                    m.private.handleEventsForEval(launchDarklyLocalState)

                    return launchDarklyParamsFallback
                else
                    launchDarklyLocalTypeMatch = true
                    if launchDarklyParamStrong <> invalid then
                        if getInterface(launchDarklyLocalFlag.value, launchDarklyParamStrong) = invalid then
                            m.private.logger.error("eval type mismatch")

                            launchDarklyLocalTypeMatch = false
                        end if
                    end if

                    launchDarklyLocalValue = invalid
                    if launchDarklyLocalTypeMatch = true then
                        launchDarklyLocalValue = launchDarklyLocalFlag.value
                    else
                        launchDarklyLocalValue = launchDarklyParamFallback
                    end if

                    launchDarklyLocalState = {
                        value: launchDarklyLocalValue,
                        flagKey: launchDarklyParamFlagKey,
                        flag: launchDarklyLocalFlag,
                        fallback: launchDarklyLocalFallback,
                        typeMatch: launchDarklyLocalTypeMatch
                    }

                    m.private.handleEventsForEval(launchDarklyLocalState)

                    return launchDarklyLocalValue
                end if
            end if
        end function,

        intVariation: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Integer) as Integer
            return m.variation(launchDarklyParamFlagKey, launchDarklyParamFallback, "ifInt")
        end function,

        boolVariation: function(flagKey as String, fallback as Boolean) as Boolean
            return m.variation(launchDarklyParamFlagKey, launchDarklyParamFallback, "ifBoolean")
        end function,

        stringVariation: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as String) as String
            return m.variation(launchDarklyParamFlagKey, launchDarklyParamFallback, "ifString")
        end function,

        aaVariation: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Object) as Object
            return m.variation(launchDarklyParamFlagKey, launchDarklyParamFallback, "ifAssociativeArray")
        end function,

        allFlags: function() as Object
            launchDarklyLocalResult = {}

            launchDarklyLocalAllFlags = m.private.lookupAll()

            for each launchDarklyLocalKey in launchDarklyLocalAllFlags
                launchDarklyLocalResult[launchDarklyLocalKey] = launchDarklyLocalAllFlags[launchDarklyLocalKey].value
            end for

            return launchDarklyLocalResult
        end function,
    }
end function

function LaunchDarklyClient(config as Object, user as Object, messagePort as Object) as Object
    store = LaunchDarklyStore(config.private.storeBackend)

    this = {
        private: {
            user: user,
            encodedUser: LaunchDarklyUserEncode(user, true, config),

            config: config,
            messagePort: messagePort,
            store: store,
            logger: config.private.logger,

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
                buffer.fromAsciiString(FormatJSON(LaunchDarklyUserEncode(m.user, false)))
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
            end function,

            REM used to abstract eval
            lookupFlag: function(flagKey) as Object
                return m.store.get(flagKey)
            end function,

            REM used to abstract eval
            isOffline: function() as Boolean
                return m.config.private.offline
            end function,

            REM used to abstract eval
            lookupAll: function() as Object
                return m.store.getAll()
            end function,

            handleEventsForEval: function(bundle as Object) as Void
                b = bundle
                m.summarizeEval(b.value, b.flagKey, b.flag, b.fallback, b.typeMatch)

                if b.flag <> invalid then
                    now = m.util.getMilliseconds()

                    shouldTrack = b.flag.trackEvents <> invalid AND b.flag.trackEvents = true
                    shouldDebug = b.flag.debugEventsUntilDate <> invalid AND b.flag.debugEventsUntilDate > now

                    if shouldTrack OR shouldDebug then
                       event = m.makeFeatureEvent(b.flag, b.fallback)

                       m.enqueueEvent(event)
                    end if
                end if
            end function,
        },

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
            m.private.encodedUser = LaunchDarklyUserEncode(m.private.user, true, m.private.config)
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

    this.append(LaunchDarklyClientSharedFunctions())

    this.private.prepareEventTransfer()
    this.private.preparePolling()

    this.handleMessage(invalid)

    return this
end function
