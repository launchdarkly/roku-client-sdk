function LaunchDarklyEventProcessor(launchDarklyParamConfig as Object, context as Object)
    launchDarklyLocalThis = {
        private: {
            config: launchDarklyParamConfig,
            util: LaunchDarklyUtility(),

            context: context,
            encodedContext: LaunchDarklyContextEncode(context),

            events: createObject("roArray", 0, true),
            summary: {},
            summaryStart: 0,

            getFlagVersion: function(launchDarklyParamFlag as Object) as Integer
                if launchDarklyParamFlag.flagVersion <> invalid then
                    return launchDarklyParamFlag.flagVersion
                else
                    return launchDarklyParamFlag.version
                end if
            end function,

            enqueueEvent: function(launchDarklyParamEvent as Object) as Void
                if m.events.count() < m.config.private.eventsCapacity then
                    m.events.push(launchDarklyParamEvent)
                else
                    m.config.private.logger.warn("eventsCapacity exceeded dropping event")
                end if
            end function,

            makeBaseEvent: function(launchDarklyParamKind as String) as Object
                launchDarklyLocalBaseEvent = {
                    kind: launchDarklyParamKind,
                    context: m.encodedContext
                }

                launchDarklyLocalBaseEvent["creationDate"] = m.util.getMilliseconds()

                return launchDarklyLocalBaseEvent
            end function,

            makeFeatureEvent: function(launchDarklyParamBundle as Object, isDebugEvent as Boolean) as Object
                launchDarklyLocalEvent = m.makeBaseEvent("feature")

                if isDebugEvent then
                  launchDarklyLocalEvent.kind = "debug"
                else
                  launchDarklyLocalEvent.delete("context")
                  launchDarklyLocalEvent["contextKeys"] = m.context.keys()
                end if

                launchDarklyLocalEvent.key = launchDarklyParamBundle.flagKey
                launchDarklyLocalEvent.version = m.getFlagVersion(launchDarklyParamBundle.flag)
                launchDarklyLocalEvent.variation = launchDarklyParamBundle.flag.variation
                launchDarklyLocalEvent.value = launchDarklyParamBundle.value
                launchDarklyLocalEvent.default = launchDarklyParamBundle.fallback

                if launchDarklyParamBundle.reason <> invalid then
                    launchDarklyLocalEvent.reason = launchDarklyParamBundle.reason
                end if

                return launchDarklyLocalEvent
            end function,

            makeSummaryEvent: function() as Object
                launchDarklyLocalEvent = {}
                launchDarklyLocalEvent["kind"] = "summary"
                launchDarklyLocalEvent["startDate"] = m.summaryStart
                launchDarklyLocalEvent["endDate"] = m.util.getMilliseconds()
                launchDarklyLocalEvent.features = {}

                for each launchDarklyLocalFeatureKey in m.summary
                    launchdarklyLocalFeature = m.summary.lookup(launchDarklyLocalFeatureKey)

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

                    launchDarklyLocalEvent.features.addReplace(launchDarklyLocalFeatureKey, launchDarklyLocalFeatureNode)
                end for

                return launchDarklyLocalEvent
            end function,

            makeIdentifyEvent: function(context as Object) as Object
                launchDarklyLocalEvent = m.makeBaseEvent("identify")
                launchDarklyLocalEvent.key = context.fullKey()
                return launchDarklyLocalEvent
            end function,

            summarizeEval: function(launchDarklyParamValue as Dynamic, launchDarklyParamFlagKey as String, launchDarklyParamFlag as Object, launchDarklyParamFallback as Dynamic, launchDarklyParamTypeMatch as Boolean) as Void
                launchDarklyLocalSummary = m.summary.lookup(launchDarklyParamFlagKey)

                if launchDarklyLocalSummary = invalid then
                    launchDarklyLocalSummary = {}
                    m.summary.addReplace(launchDarklyParamFlagKey, launchDarklyLocalSummary)
                    launchDarklyLocalSummary.default = launchDarklyParamFallback
                    launchDarklyLocalSummary.counters = {}
                end if

                if m.summaryStart = 0 then
                    m.summaryStart = m.util.getMilliseconds()
                end if

                launchDarklyLocalCounterKey = invalid

                if launchDarklyParamFlag = invalid then
                    launchDarklyLocalCounterKey = "unknown"
                else if launchDarklyParamTypeMatch = false then
                    launchDarklyLocalCounterKey = "default"
                else if launchDarklyParamFlag.variation <> invalid then
                    launchDarklyLocalCounterKey = m.getFlagVersion(launchDarklyParamFlag).toStr() + " " + launchDarklyParamFlag.variation.toStr()
                else
                    launchDarklyLocalCounterKey = m.getFlagVersion(launchDarklyParamFlag).toStr()
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
            end function
        },

        flush: function() as Dynamic
            if m.private.summaryStart <> 0 then
                launchDarklyLocalSummary = m.private.makeSummaryEvent()
                m.private.events.push(launchDarklyLocalSummary)
                m.private.summary = {}
                m.private.summaryStart = 0
            end if

            if m.private.events.count() = 0 then
                return invalid
            end if

            launchDarklyLocalEvents = m.private.events

            m.private.events = createObject("roArray", 0, true)

            return launchDarklyLocalEvents
        end function,

        track: function(launchDarklyParamKey as String, launchDarklyParamData=invalid as Object, launchDarklyParamMetric=invalid as Dynamic) as Void
            launchDarklyLocalEvent = m.private.makeBaseEvent("custom")
            launchDarklyLocalEvent.key = launchDarklyParamKey

            launchDarklyLocalEvent.delete("context")
            launchDarklyLocalEvent["contextKeys"] = m.private.context.keys()

            if launchDarklyParamData <> invalid then
                launchDarklyLocalEvent.data = launchDarklyParamData
            end if

            if launchDarklyParamMetric <> invalid then
                launchDarklyLocalEvent["metricValue"] = launchDarklyParamMetric
            end if

            m.private.enqueueEvent(launchDarklyLocalEvent)
        end function,

        identify: function(context as Object) as Void
            m.private.context = context
            m.private.encodedContext = LaunchDarklyContextEncode(m.private.context)

            m.private.enqueueEvent(m.private.makeIdentifyEvent(context))
        end function,

        handleEventsForEval: function(launchDarklyParamBundle as Object) as Void
            m.private.summarizeEval(launchDarklyParamBundle.value, launchDarklyParamBundle.flagKey, launchDarklyParamBundle.flag, launchDarklyParamBundle.fallback, launchDarklyParamBundle.typeMatch)

            if launchDarklyParamBundle.flag <> invalid then
                launchDarklyLocalNow = m.private.util.getMilliseconds()

                launchDarklyLocalShouldTrack = launchDarklyParamBundle.flag.trackEvents <> invalid AND launchDarklyParamBundle.flag.trackEvents = true
                launchDarklyLocalShouldDebug = launchDarklyParamBundle.flag.debugEventsUntilDate <> invalid AND launchDarklyParamBundle.flag.debugEventsUntilDate > launchDarklyLocalNow

                if launchDarklyLocalShouldTrack OR launchDarklyLocalShouldDebug then
                   launchDarklyLocalEvent = m.private.makeFeatureEvent(launchDarklyParamBundle, launchDarklyLocalShouldDebug)

                   m.private.enqueueEvent(launchDarklyLocalEvent)
                end if
            end if
        end function
    }

    return LaunchDarklyLocalThis
end function
