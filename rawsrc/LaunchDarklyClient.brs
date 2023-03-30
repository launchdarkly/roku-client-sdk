function LaunchDarklyClientSharedFunctions(launchDarklyParamSceneGraphNode as Object) as Object
    return {
        variationDetail: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Dynamic, launchDarklyParamEmbedReason=true as Boolean, launchDarklyParamStrong=invalid as Dynamic) as Object
            if m.status.getStatus() <> m.status.map.initialized then
                launchDarklyLocalReason = {}
                launchDarklyLocalReason["kind"] = "ERROR"
                launchDarklyLocalReason["errorKind"] = "CLIENT_NOT_READY"

                launchDarklyLocalDetails = {}
                launchDarklyLocalDetails["result"] = launchDarklyParamFallback
                launchDarklyLocalDetails["reason"] = launchDarklyLocalReason

                return launchDarklyLocalDetails
            else
                launchDarklyLocalFlag = m.private.lookupFlag(launchDarklyParamFlagKey)

                if launchDarklyLocalFlag = invalid or launchDarklyLocalFlag.deleted = true then
                    m.private.logger.error("missing flag")

                    launchDarklyLocalReason = {}
                    launchDarklyLocalReason["kind"] = "ERROR"
                    launchDarklyLocalReason["errorKind"] = "FLAG_NOT_FOUND"

                    launchDarklyLocalState = {
                        value: launchDarklyParamFallback,
                        flagKey: launchDarklyParamFlagKey,
                        flag: invalid,
                        fallback: launchDarklyParamFallback,
                        typeMatch: true
                    }

                    if launchDarklyParamEmbedReason = true then
                        launchDarklyLocalState.reason = LaunchDarklyUtility().deepCopy(launchDarklyLocalReason)
                    end if

                    m.private.handleEventsForEval(launchDarklyLocalState)

                    launchDarklyLocalDetails = {}
                    launchDarklyLocalDetails["result"] = launchDarklyParamFallback
                    launchDarklyLocalDetails["reason"] = launchDarklyLocalReason

                    return launchDarklyLocalDetails
                else
                    launchDarklyLocalReason = {}
                    launchDarklyLocalTypeMatch = true
                    launchDarklyLocalValue = invalid

                    if launchDarklyParamStrong <> invalid then
                        if launchDarklyParamStrong(launchDarklyLocalFlag.value) = true then
                            launchDarklyLocalValue = launchDarklyLocalFlag.value
                        else
                            m.private.logger.error("eval type mismatch")

                            launchDarklyLocalValue = launchDarklyParamFallback

                            launchDarklyLocalTypeMatch = false
                        end if
                    else
                        launchDarklyLocalValue = launchDarklyLocalFlag.value
                    end if

                    if launchDarklyLocalTypeMatch OR launchDarklyLocalFlag.value = invalid then
                        if launchDarklyLocalFlag.reason <> invalid then
                            launchDarklyLocalReason = LaunchDarklyUtility().deepCopy(launchDarklyLocalFlag.reason)
                        end if
                    else
                        launchDarklyLocalReason["kind"] = "ERROR"
                        launchDarklyLocalReason["errorKind"] = "WRONG_TYPE"
                    end if

                    launchDarklyLocalState = {
                        value: launchDarklyLocalValue,
                        flagKey: launchDarklyParamFlagKey,
                        flag: launchDarklyLocalFlag,
                        fallback: launchDarklyParamFallback,
                        typeMatch: launchDarklyLocalTypeMatch
                    }

                    if launchDarklyParamEmbedReason = true OR launchDarklyLocalFlag.trackReason = true then
                        launchDarklyLocalState.reason = LaunchDarklyUtility().deepCopy(launchDarklyLocalReason)
                    end if

                    m.private.handleEventsForEval(launchDarklyLocalState)

                    launchDarklyLocalDetails = {}
                    launchDarklyLocalDetails["result"] = launchDarklyLocalValue
                    launchDarklyLocalDetails["reason"] = launchDarklyLocalReason

                    if launchDarklyLocalTypeMatch = true then
                      launchDarklyLocalDetails["variationIndex"] = launchDarklyLocalFlag.variation
                    end if

                    return launchDarklyLocalDetails
                end if
            end if
        end function,

        intVariationDetail: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Integer, launchDarklyParamEmbedReason=true as Dynamic) as Object
            launchDarklyLocalResult = m.doubleVariationDetail(launchDarklyParamFlagKey, launchDarklyParamFallback, launchDarklyParamEmbedReason)
            launchDarklyLocalResult.result = int(launchDarklyLocalResult.result)
            return launchDarklyLocalResult
        end function,

        boolVariationDetail: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Boolean, launchDarklyParamEmbedReason=true as Dynamic) as Object
            return m.variationDetail(launchDarklyParamFlagKey, launchDarklyParamFallback, launchDarklyParamEmbedReason, function(launchDarklyParamValue as Dynamic) as Boolean
                return getInterface(launchDarklyParamValue, "ifBoolean") <> invalid
            end function)
        end function,

        stringVariationDetail: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as String, launchDarklyParamEmbedReason=true as Dynamic) as Object
            return m.variationDetail(launchDarklyParamFlagKey, launchDarklyParamFallback, launchDarklyParamEmbedReason, function(launchDarklyParamValue as Dynamic) as Boolean
                return getInterface(launchDarklyParamValue, "ifString") <> invalid
            end function)
        end function,

        jsonVariationDetail: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Object, launchDarklyParamEmbedReason=true as Dynamic) as Object
            return m.variationDetail(launchDarklyParamFlagKey, launchDarklyParamFallback, launchDarklyParamEmbedReason, function(launchDarklyParamValue as Dynamic) as Boolean
                if getInterface(launchDarklyParamValue, "ifAssociativeArray") <> invalid then
                    return true
                else if getInterface(launchDarklyParamValue, "ifArray") <> invalid then
                    return true
                else
                    return false
                end if
            end function)
        end function,

        doubleVariationDetail: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Double, launchDarklyParamEmbedReason=true as Dynamic) as Object
            launchDarklyLocalResult = m.variationDetail(launchDarklyParamFlagKey, launchDarklyParamFallback, launchDarklyParamEmbedReason, function(launchDarklyParamValue as Dynamic) as Boolean
                if getInterface(launchDarklyParamValue, "ifFloat") <> invalid then
                    return true
                else if getInterface(launchDarklyParamValue, "ifDouble") <> invalid then
                    return true
                else if getInterface(launchDarklyParamValue, "ifInt") <> invalid then
                    return true
                else
                    return false
                end if
            end function)
            launchDarklyLocalValue# = launchDarklyLocalResult.result
            launchDarklyLocalResult.result = launchDarklyLocalValue#
            return launchDarklyLocalResult
        end function,

        variation: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Dynamic, launchDarklyParamStrong=invalid as Dynamic) as Dynamic
            return m.variationDetail(launchDarklyParamFlagKey, launchDarklyParamFallback, false, launchDarklyParamStrong).result
        end function,

        intVariation: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Integer) as Integer
            return m.intVariationDetail(launchDarklyParamFlagKey, launchDarklyParamFallback, false).result
        end function,

        boolVariation: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Boolean) as Boolean
            return m.boolVariationDetail(launchDarklyParamFlagKey, launchDarklyParamFallback, false).result
        end function,

        stringVariation: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as String) as String
            return m.stringVariationDetail(launchDarklyParamFlagKey, launchDarklyParamFallback, false).result
        end function,

        jsonVariation: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Object) as Object
            return m.jsonVariationDetail(launchDarklyParamFlagKey, launchDarklyParamFallback, false).result
        end function,

        doubleVariation: function(launchDarklyParamFlagKey as String, launchDarklyParamFallback as Double) as Double
            return m.doubleVariationDetail(launchDarklyParamFlagKey, launchDarklyParamFallback, false).result
        end function,

        allFlags: function() as Object
            launchDarklyLocalResult = {}

            launchDarklyLocalAllFlags = m.private.lookupAll()

            for each launchDarklyLocalKey in launchDarklyLocalAllFlags
                launchDarklyLocalResult[launchDarklyLocalKey] = launchDarklyLocalAllFlags[launchDarklyLocalKey].value
            end for

            return launchDarklyLocalResult
        end function,

        allFlagsState: function() as Object
            results = {
              "$flagsState": {},
              "$valid": true
            }

            launchDarklyLocalAllFlags = m.private.lookupAll()
            for each launchDarklyLocalKey in launchDarklyLocalAllFlags
                result = launchDarklyLocalAllFlags[launchDarklyLocalKey]

                if result.lookup("deleted") <> true then
                  results[launchDarklyLocalKey] = result.value
                  results["$flagsState"][launchDarklyLocalKey] = { "variation": result.variation, "version": result.version }
                end if
            end for

            return results
        end function

        status: {
            private: {
                status: 0,

                sceneGraphNode: launchDarklyParamSceneGraphNode,

                setStatus: function(launchDarklyParamStatus as Integer) as Void
                    if m.sceneGraphNode <> invalid then
                        m.sceneGraphNode.status = launchDarklyParamStatus
                    else
                        m.status = launchDarklyParamStatus
                    end if
                end function,

                getStatus: function() as Integer
                    if m.sceneGraphNode <> invalid then
                        return m.sceneGraphNode.status
                    else
                        return m.status
                    end if
                end function
            },

            map: {
                uninitialized: 0,
                unauthorized: 1,
                initialized: 2
            },

            getStatusAsString: function() as String
                launchDarklyLocalStatus = m.private.getStatus()

                if launchDarklyLocalStatus = m.map.uninitialized then
                    return "uninitialized"
                else if launchDarklyLocalStatus = m.map.unauthorized then
                    return "unauthorized"
                else if launchDarklyLocalStatus = m.map.initialized then
                    return "initialized"
                end if
            end function

            getStatus: function() as Integer
                return m.private.getStatus()
            end function
        }
    }
end function

function LaunchDarklyClient(launchDarklyParamConfig as Object, context as Object, launchDarklyParamMessagePort as Object) as Object
    launchDarklyLocalStore = LaunchDarklyStore(launchDarklyParamConfig.private.storeBackend)

    launchDarklyLocalThis = {
        private: {
            context: context,
            encodedContext: LaunchDarklyContextEncode(context, true, launchDarklyParamConfig),

            config: launchDarklyParamConfig,
            messagePort: launchDarklyParamMessagePort,
            store: launchDarklyLocalStore,
            logger: launchDarklyParamConfig.private.logger,

            pollingInitial: true,
            pollingTransfer: createObject("roUrlTransfer"),
            pollingTimer: createObject("roTimeSpan"),
            pollingActive: false,

            eventProcessor: LaunchDarklyEventProcessor(launchDarklyParamConfig, context),
            eventsTransfer: createObject("roUrlTransfer"),
            eventsFlushTimer: createObject("roTimeSpan"),
            eventsFlushActive: false,
            eventsFailureRetrying: false,
            eventsPayloadId: invalid,
            eventsPayload: invalid,

            streamClient: invalid,

            util: LaunchDarklyUtility(),

            eventHeaders: {
              "Content-Type": "application/json",
              "X-LaunchDarkly-Event-Schema": "4",
            },

            handlePollingMessage: function(launchDarklyParamCtx as Object, launchDarklyParamMessage as Dynamic) as Void
                launchDarklyLocalResponseCode = launchDarklyParamMessage.getResponseCode()

                m.config.private.logger.debug("polling response code: " + launchDarklyLocalResponseCode.toStr())

                if launchDarklyLocalResponseCode >= 200 AND launchDarklyLocalResponseCode < 300 then
                    launchDarklyLocalDecoded = parseJSON(launchDarklyParamMessage.getString())

                    if launchDarklyLocalDecoded = invalid then
                        m.config.private.logger.error("failed json decoding")
                    else
                        m.config.private.logger.debug("updating store")

                        m.store.putAll(launchDarklyLocalDecoded)

                        launchDarklyParamCtx.status.private.setStatus(launchDarklyParamCtx.status.map.initialized)
                    end if
                end if

                if launchDarklyLocalResponseCode = 401 OR launchDarklyLocalResponseCode = 403 then
                    m.config.private.logger.error("polling not authorized")

                    launchDarklyParamCtx.status.private.setStatus(launchDarklyParamCtx.status.map.unauthorized)
                else
                    m.resetPollingTransfer()
                end if
            end function,

            handleEventsMessage: function(launchDarklyParamCtx as Object, launchDarklyParamMessage as Dynamic) as Void
                launchDarklyLocalResponseCode = launchDarklyParamMessage.getResponseCode()

                m.config.private.logger.debug("events response code: " + launchDarklyLocalResponseCode.toStr())

                launchDarklyLocalRetryable = false

                if launchDarklyLocalResponseCode >= 200 AND launchDarklyLocalResponseCode < 300 then
                    m.config.private.logger.debug("events sent")
                else if launchDarklyLocalResponseCode = 401 OR launchDarklyLocalResponseCode = 403 then
                    m.config.private.logger.error("events not authorized")

                    launchDarklyParamCtx.status.private.setStatus(launchDarklyParamCtx.status.map.unauthorized)
                else
                    launchDarklyLocalRetryable = true
                end if

                if launchDarklyLocalRetryable = true AND m.eventsFailureRetrying = false then
                    m.eventsFailureRetrying = true
                else
                    m.eventsFailureRetrying = false
                end if

                m.resetEventsTransfer()
            end function,

            preparePolling: function() as Void
                launchDarklyLocalBuffer = createObject("roByteArray")
                launchDarklyLocalBuffer.fromAsciiString(FormatJSON(LaunchDarklyContextEncode(m.context, false)))
                launchDarklyLocalContextBase64JSON = launchDarklyLocalBuffer.toBase64String()
                launchDarklyLocalUrl = m.config.private.appURI + "/msdk/evalx/contexts/" + launchDarklyLocalContextBase64JSON

                if m.config.private.useReasons then
                    launchDarklyLocalUrl += "?withReasons=true"
                end if

                m.config.private.logger.debug("polling url: " + launchDarklyLocalUrl)

                m.pollingTransfer = createObject("roUrlTransfer")
                m.util.prepareNetworkingCommon(m.messagePort, m.config, m.pollingTransfer, {})
                m.pollingTransfer.setURL(launchDarklyLocalUrl)
            end function,

            prepareEventTransfer: function() as Void
                launchDarklyLocalUrl = m.config.private.eventsURI + "/mobile"

                m.config.private.logger.debug("events url: " + launchDarklyLocalUrl)

                m.util.prepareNetworkingCommon(m.messagePort, m.config, m.eventsTransfer, m.eventHeaders)
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
                m.eventProcessor.handleEventsForEval(launchDarklyParamBundle)
            end function
        },

        track: function(launchDarklyParamKey as String, launchDarklyParamData=invalid as Object, launchDarklyParamMetric=invalid as Dynamic) as Void
            m.private.eventProcessor.track(launchDarklyParamKey, launchDarklyParamData, launchDarklyParamMetric)
        end function,

        flush: function() as Void
            if m.private.config.private.offline = false then
                if m.private.eventsFlushActive = false then
                    if m.private.eventsFailureRetrying = false then
                        launchDarklyLocalEvents = m.private.eventProcessor.flush()

                        if launchDarklyLocalEvents = invalid then
                            m.private.resetEventsTransfer()

                            m.private.config.private.logger.debug("event payload empty skipping post")

                            return
                        end if

                        m.private.eventsPayload = formatJSON(launchDarklyLocalEvents)

                        m.private.eventsPayloadId = createObject("roDeviceInfo").getRandomUUID()
                    end if

                    m.private.eventsFlushActive = true

                    m.private.eventHeaders["X-LaunchDarkly-Payload-ID"] = m.private.eventsPayloadId
                    m.private.eventsTransfer.setHeaders(m.private.eventHeaders)

                    m.private.eventsTransfer.asyncPostFromString(m.private.eventsPayload)
                end if
            end if
        end function,

        identify: function(context as Object) as Void
            m.status.private.setStatus(m.status.map.uninitialized)

            m.private.context = context

            m.private.eventProcessor.identify(context)
            m.private.streamClient.changeContext(context)

            m.private.resetPollingTransfer()
            m.private.preparePolling()
            m.private.pollingInitial = true

            m.handleMessage(invalid)
        end function,

        handleMessage: function(launchDarklyParamMessage=invalid as Dynamic) as Boolean
            if m.status.getStatus() <> m.status.map.unauthorized AND m.private.config.private.offline = false then
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

                    if m.private.eventsFailureRetrying = true AND launchDarklyLocalElapsed >= 1 then
                        m.private.config.private.logger.debug("flush retry timeout hit")

                        m.flush()
                    else if launchDarklyLocalElapsed >= m.private.config.private.eventsFlushIntervalSeconds then
                        m.private.config.private.logger.debug("flush timeout hit")

                        m.flush()
                    end if
                end if
            end if

            if m.private.streamClient.handleMessage(launchDarklyParamMessage) then
                return true
            else if type(launchDarklyParamMessage) = "roUrlEvent" then
                launchDarklyLocalEventId = launchDarklyParamMessage.getSourceIdentity()

                launchDarklyLocalPollingId = m.private.pollingTransfer.getIdentity()
                launchDarklyLocalEventsId = m.private.eventsTransfer.getIdentity()

                if launchDarklyLocalEventId = launchDarklyLocalPollingId then
                    m.private.handlePollingMessage(m, launchDarklyParamMessage)

                    return true
                else if launchDarklyLocalEventId = launchDarklyLocalEventsId then
                    m.private.handleEventsMessage(m, launchDarklyParamMessage)

                    return true
                end if
            end if

            return false
        end function
    }

    launchDarklyLocalThis.append(LaunchDarklyClientSharedFunctions(launchDarklyParamConfig.private.sceneGraphNode))

    launchDarklyLocalThis.private.streamClient = LaunchDarklyStreamClient(launchDarklyParamConfig, launchDarklyLocalStore, launchDarklyParamMessagePort, context, launchDarklyLocalThis.status)

    launchDarklyLocalThis.private.prepareEventTransfer()
    launchDarklyLocalThis.private.preparePolling()

    launchDarklyLocalThis.private.eventProcessor.identify(context)

    launchDarklyLocalThis.handleMessage(invalid)

    return launchDarklyLocalThis
end function
