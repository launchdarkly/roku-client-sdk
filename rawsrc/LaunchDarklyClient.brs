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
                        fallback: launchDarklyParamFallback,
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

function LaunchDarklyClient(launchDarklyParamConfig as Object, launchDarklyParamUser as Object, launchDarklyParamMessagePort as Object) as Object
    launchDarklyLocalStore = LaunchDarklyStore(launchDarklyParamConfig.private.storeBackend)

    launchDarklyLocalThis = {
        private: {
            user: launchDarklyParamUser,
            encodedUser: LaunchDarklyUserEncode(launchDarklyParamUser, true, launchDarklyParamConfig),

            config: launchDarklyParamConfig,
            messagePort: launchDarklyParamMessagePort,
            store: launchDarklyLocalStore,
            logger: launchDarklyParamConfig.private.logger,

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

            streamClient: LaunchDarklyStreamClient(launchDarklyParamConfig, launchDarklyLocalStore, launchDarklyParamMessagePort, launchDarklyParamUser),

            util: LaunchDarklyUtility(),

            handlePollingMessage: function(launchDarklyParamMessage as Dynamic) as Void
                launchDarklyLocalResponseCode = launchDarklyParamMessage.getResponseCode()

                m.config.private.logger.debug("polling response code: " + launchDarklyLocalResponseCode.toStr())

                if launchDarklyLocalResponseCode >= 200 AND launchDarklyLocalResponseCode < 300 then
                    launchDarklyLocalDecoded = parseJSON(launchDarklyParamMessage.getString())

                    if launchDarklyLocalDecoded = invalid then
                        m.config.private.logger.error("failed json decoding")
                    else
                        m.config.private.logger.debug("updating store")

                        m.store.putAll(launchDarklyLocalDecoded)
                    end if
                end if

                if launchDarklyLocalResponseCode = 401 OR launchDarklyLocalResponseCode = 403 then
                    m.config.private.logger.error("polling not authorized")

                    m.unauthorized = true
                else
                    m.resetPollingTransfer()
                end if
            end function,

            handleEventsMessage: function(launchDarklyParamMessage as Dynamic) as Void
                launchDarklyLocalResponseCode = launchDarklyParamMessage.getResponseCode()

                m.config.private.logger.debug("events response code: " + launchDarklyLocalResponseCode.toStr())

                if launchDarklyLocalResponseCode >= 200 AND launchDarklyLocalResponseCode < 300 then
                    m.config.private.logger.debug("events sent")
                end if

                if launchDarklyLocalResponseCode = 401 OR launchDarklyLocalResponseCode = 403 then
                    m.config.private.logger.error("events not authorized")

                    m.unauthorized = true
                else
                    m.resetEventsTransfer()
                end if
            end function,

            getFlagVersion: function(launchDarklyParamFlag as Object) as Integer
                if launchDarklyParamFlag.flagVersion <> invalid then
                    return launchDarklyParamFlag.flagVersion
                else
                    return launchDarklyParamFlag.version
                end if
            end function,

            makeBaseEvent: function(launchDarklyParamKind as String) as Object
                return {
                    kind: launchDarklyParamKind,
                    user: m.encodedUser,
                    creationDate: m.util.getMilliseconds()
                }
            end function,

            makeFeatureEvent: function(launchDarklyParamFlag as Object, launchDarklyParamFallback as Dynamic) as Object
                launchDarklyLocalEvent = m.makeBaseEvent("feature")

                launchDarklyLocalEvent.version = m.getFlagVersion(launchDarklyParamFlag)
                launchDarklyLocalEvent.variation = launchDarklyParamFlag.variation
                launchDarklyLocalEvent.value = launchDarklyParamFlag.value
                launchDarklyLocalEvent.default = launchDarklyParamFallback

                return launchDarklyLocalEvent
            end function,

            makeSummaryEvent: function() as Object
                launchDarklyLocalEvent = m.makeBaseEvent("summary")
                launchDarklyLocalEvent.startDate = m.eventsSummaryStart
                launchDarklyLocalEvent.endDate = m.util.getMilliseconds()
                launchDarklyLocalEvent.features = {}

                for each launchDarklyLocalFeatureKey in m.eventsSummary
                    launchdarklyLocalFeature = m.eventsSummary.lookup(launchDarklyLocalFeatureKey)

                    launchDarklyLocalFeatureNode = {
                        default: launchDarklyLocalFeature.default,
                        counters: createObject("roArray", 0, true)
                    }

                    for each launchDarklyLocalCounterKey in launchDarklyLocalFeature.counters
                        launchDarklyLocalCounter = launchDarklyLocalFeature.counters.lookup(launchDarklyLocalCounterKey)

                        launchDarklyLocalCounterNode = {
                            count: launchDarklyLocalCounter.count,
                            value: launchdarklyLocalCounter.value
                        }

                        if launchDarklyLocalCounter.version <> invalid then
                            launchDarklyLocalCounterNode.version = launchDarklyLocalCounter.version
                        end if

                        if launchDarklyLocalCounter.variation <> invalid then
                            launchDarklyLocalCounterNode.variation = launchDarklyLocalCounter.variation
                        end if

                        if launchDarklyLocalCounterKey = "unknown" then
                            launchDarklyLocalCounterNode.unknown = true
                        end if

                        launchDarklyLocalFeatureNode.counters.push(launchDarklyLocalCounterNode)
                    end for

                    launchDarklyLocalEvent.features.addReplace(featureKey, featureNode)
                end for

                return launchDarklyLocalEvent
            end function,

            summarizeEval: function(launchDarklyParamValue as Dynamic, launchDarklyParamFlagKey as String, launchDarklyParamFlag as Object, launchDarklyParamFallback as Dynamic, launchDarklyParamTypeMatch as Boolean) as Void
                launchDarklyLocalSummary = m.eventsSummary.lookup(launchDarklyParamFlagKey)

                if launchDarklyLocalSummary = invalid then
                    launchDarklyLocalSummary = {}
                    m.eventsSummary.addReplace(launchDarklyParamFlagKey, launchDarklyLocalSummary)
                    launchDarklyLocalSummary.default = launchDarklyParamFallback
                    launchDarklyLocalSummary.counters = {}
                end if

                if m.eventsSummaryStart = 0 then
                    m.eventsSummaryStart = m.util.getMilliseconds()
                end if

                launchDarklyLocalCounterKey = invalid

                if launchDarklyParamFlag = invalid then
                    launchDarklyLocalCounterKey = "unknown"
                else if launchDarklyParamTypeMatch = false then
                    launchDarklyLocalCounterKey = "default"
                else
                    launchDarklyLocalCounterKey = m.getFlagVersion(launchDarklyParamFlag).toStr() + " " + launchDarklyParamFlag.variation.toStr()
                end if

                launchDarklyLocalCounter = launchDarklyLocalSummary.counters.lookup(launchDarklyLocalCounterKey)

                if launchDarklyLocalCounter = invalid then
                    launchDarklyLocalCounter = {
                        value: launchDarklyParamValue,
                        count: 0
                    }

                    launchDarklyLocalSummary.counters.addReplace(launchDarklyLocalCounterKey, launchDarklyLocalCounter)
                end if

                if launchDarklyParamFlag <> invalid AND launchDarklyLocalCounter.count = 0 then
                    launchDarklyLocalCounter.version = m.getFlagVersion(launchDarklyParamFlag)
                    launchDarklyLocalCounter.variation = launchDarklyParamFlag.variation
                end if

                launchDarklyLocalCounter.count += 1
            end function,

            enqueueEvent: function(launchDarklyParamEvent as Object) as Void
                if m.events.count() < m.config.private.eventsCapacity then
                    m.events.push(launchDarklyParamEvent)
                else
                    m.config.private.logger.warn("eventsCapacity exceeded dropping event")
                end if
            end function,

            preparePolling: function() as Void
                launchDarklyLocalBuffer = createObject("roByteArray")
                launchDarklyLocalBuffer.fromAsciiString(FormatJSON(LaunchDarklyUserEncode(m.user, false)))
                launchDarklyLocalUserBase64JSON = launchDarklyLocalBuffer.toBase64String()
                launchDarklyLocalUrl = m.config.private.appURI + "/msdk/evalx/users/" + launchDarklyLocalUserBase64JSON

                m.config.private.logger.debug("polling url: " + launchDarklyLocalUrl)

                m.util.prepareNetworkingCommon(m.messagePort, m.config, m.pollingTransfer)
                m.pollingTransfer.setURL(launchDarklyLocalUrl)
            end function,

            prepareEventTransfer: function() as Void
                launchDarklyLocalUrl = m.config.private.eventsURI + "/mobile"

                m.config.private.logger.debug("events url: " + launchDarklyLocalUrl)

                m.util.prepareNetworkingCommon(m.messagePort, m.config, m.eventsTransfer)
                m.eventsTransfer.addHeader("Content-Type", "application/json")
                m.eventsTransfer.addHeader("X-LaunchDarkly-Event-Schema", "3")
                m.eventsTransfer.setURL(launchDarklyLocalUrl)
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
            lookupFlag: function(launchDarklyParamFlagKey) as Object
                return m.store.get(launchDarklyParamFlagKey)
            end function,

            REM used to abstract eval
            isOffline: function() as Boolean
                return m.config.private.offline
            end function,

            REM used to abstract eval
            lookupAll: function() as Object
                return m.store.getAll()
            end function,

            handleEventsForEval: function(launchDarklyParamBundle as Object) as Void
                m.summarizeEval(launchDarklyParamBundle.value, launchDarklyParamBundle.flagKey, launchDarklyParamBundle.flag, launchDarklyParamBundle.fallback, launchDarklyParamBundle.typeMatch)

                if launchDarklyParamBundle.flag <> invalid then
                    launchDarklyLocalNow = m.util.getMilliseconds()

                    launchDarklyLocalShouldTrack = launchDarklyParamBundle.flag.trackEvents <> invalid AND launchDarklyParamBundle.flag.trackEvents = true
                    launchDarklyLocalShouldDebug = launchDarklyParamBundle.flag.debugEventsUntilDate <> invalid AND launchDarklyParamBundle.flag.debugEventsUntilDate > launchDarklyLocalNow

                    if launchDarklyLocalShouldTrack OR launchDarklyLocalShouldDebug then
                       launchDarklyLocalEvent = m.makeFeatureEvent(launchDarklyParamBundle.flag, launchDarklyParamBundle.fallback)

                       m.enqueueEvent(launchDarklyLocalEvent)
                    end if
                end if
            end function,
        },

        track: function(launchDarklyParamKey as String, launchDarklyParamData=invalid as Object) as Void
            launchDarklyLocalEvent = m.private.makeBaseEvent("custom")
            launchDarklyLocalEvent.key = launchDarklyParamKey

            if launchDarklyParamData <> invalid then
                launchDarklyLocalEvent.data = launchDarklyParamData
            end if

            m.private.enqueueEvent(launchDarklyLocalEvent)
        end function,

        flush: function() as Void
            if m.private.config.private.offline = false then
                if m.private.eventsFlushActive = false then
                    if m.private.eventsSummaryStart <> 0 then
                        launchDarklyLocalSummary = m.private.makeSummaryEvent()
                        m.private.events.push(launchDarklyLocalSummary)
                        m.private.eventsSummary = {}
                        m.private.eventsSummaryStart = 0
                    end if

                    m.private.eventsFlushActive = true
                    launchDarklySerialized = formatJSON(m.private.events)
                    m.private.events.clear()
                    m.private.eventsTransfer.asyncPostFromString(launchDarklyLocalSerialized)
                end if
            end if
        end function,

        identify: function(launchDarklyParamUser as Object) as Void
            m.private.user = launchDarklyParamUser
            m.private.encodedUser = LaunchDarklyUserEncode(m.private.user, true, m.private.config)
            launchDarklyLocalEvent = m.private.makeBaseEvent("identify")
            m.private.enqueueEvent(launchDarklyLocalEvent)

            m.private.streamClient.changeUser(launchDarklyParamUser)
            m.handleMessage(invalid)

            m.private.resetPollingTransfer()
            m.private.preparePolling()
        end function,

        handleMessage: function(launchDarklyParamMessage=invalid as Dynamic) as Boolean
            if m.private.unauthorized = false AND m.private.config.private.offline = false then
                REM start polling if timeout is hit
                if m.private.config.private.streaming = false AND m.private.pollingActive = false then
                    launchDarklyLocalElapsed = m.private.pollingTimer.totalSeconds()

                    if m.private.pollingInitial OR launchDarklyLocalElapsed >= m.private.config.private.pollingIntervalSeconds then
                        m.private.config.private.logger.debug("polling timeout hit")

                        m.private.startPollingTransfer()
                    end if
                end if

                REM flush events if timeout is hit
                if m.private.eventsFlushActive = false then
                    launchDarklyLocalElapsed = m.private.eventsFlushTimer.totalSeconds()

                    if launchDarklyLocalElapsed >= m.private.config.private.eventsFlushIntervalSeconds then
                        m.private.config.private.logger.debug("flush timeout hit")

                        m.flush()
                    end if
                end if
            end if

            if m.private.streamClient.handleMessage(launchDarklyParamMessage) then
                return true
            else if type(launchDarklyParamMessage) = "roUrlEvent" then
                launchDarklyLocalEventId = message.getSourceIdentity()

                launchDarklyLocalPollingId = m.private.pollingTransfer.getIdentity()
                launchDarklyLocalEventsId = m.private.eventsTransfer.getIdentity()

                if launchDarklyLocalEventId = launchDarklyLocalPollingId then
                    m.private.handlePollingMessage(launchDarklyParamMessage)

                    return true
                else if launchDarklyLocalEventId = launchDarklyLocalEventsId then
                    m.private.handleEventsMessage(launchDarklyParamMessage)

                    return true
                end if
            end if

            return false
        end function
    }

    launchDarklyLocalThis.append(LaunchDarklyClientSharedFunctions())

    launchDarklyLocalThis.private.prepareEventTransfer()
    launchDarklyLocalThis.private.preparePolling()

    launchDarklyLocalThis.handleMessage(invalid)

    return launchDarklyLocalThis
end function
