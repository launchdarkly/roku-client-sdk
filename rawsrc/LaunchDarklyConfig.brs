function LaunchDarklyConfig(launchDarklyParamMobileKey as String, launchDarklyParamSceneGraphNode=invalid as Dynamic) as Object
    launchDarklyLocalThis = {
        private: {
            ' WARN: Internally used flag to disable encryption handling for SDK
            ' contract testing
            forcePlainTextInStream: false,
            util: launchDarklyUtility(),
            appURI: "https://app.launchdarkly.com",
            eventsURI: "https://mobile.launchdarkly.com",
            streamURI: "https://clientstream.launchdarkly.com",
            pollingIntervalSeconds: 15,
            mobileKey: launchDarklyParamMobileKey,
            offline: false,
            privateAttributeNames: {},
            allAttributesPrivate: false,
            eventsCapacity: 100,
            eventsFlushIntervalSeconds: 30,
            logger: invalid,
            loggerNode: launchDarklyParamSceneGraphNode,
            storeBackend: invalid,
            storeBackendNode: launchDarklyParamSceneGraphNode,
            streaming: true,
            logLevel: LaunchDarklyLogLevels().warn,
            sceneGraphNode: launchDarklyParamSceneGraphNode,
            useReasons: false,
            applicationInfo: invalid,

            validateURI: function(launchDarklyParamRawURI as String) as Boolean
                launchDarklyLocalHTTPS = "https://"
                launchDarklyLocalHTTP = "http://"

                return left(launchDarklyParamRawURI, len(launchDarklyLocalHTTPS)) = launchDarklyLocalHTTPS OR left(launchDarklyParamRawURI, len(launchDarklyLocalHTTP)) = launchDarklyLocalHTTP
            end function,

            appInfoRegex: CreateObject("roRegex", "[^a-zA-Z0-9._-]", ""),
        },

        setAppURI: function(launchDarklyParamAppURI as String) as Boolean
            if m.private.validateURI(launchDarklyParamAppURI) then
                m.private.appURI = m.private.util.trimTrailingSlash(launchDarklyParamAppURI)

                return true
            else
                return false
            end if
        end function,

        setEventsURI: function(launchDarklyParamEventsURI as String) as Boolean
            if m.private.validateURI(launchDarklyParamEventsURI) then
                m.private.eventsURI = m.private.util.trimTrailingSlash(launchDarklyParamEventsURI)

                return true
            else
                return false
            end if
        end function,

        setStreamURI: function(launchDarklyParamStreamURI as String) as Boolean
            if m.private.validateURI(launchDarklyParamStreamURI) then
                m.private.streamURI = m.private.util.trimTrailingSlash(launchDarklyParamStreamURI)

                return true
            else
                return false
            end if
        end function

        setPollingIntervalSeconds: function(launchdarklyParamPollingIntervalSeconds as Integer) as Void
            m.private.pollingIntervalSeconds = launchDarklyParamPollingIntervalSeconds
        end function,

        setOffline: function(launchDarklyParamOffline as Boolean) as Void
            m.private.offline = launchDarklyParamOffline
        end function,

        addPrivateAttribute: function(launchDarklyParamPrivateAttribute as String) as Void
            m.private.privateAttributeNames.addReplace(launchDarklyParamPrivateAttribute, 1)
        end function,

        setAllAttributesPrivate: function(launchDarklyParamAllAttributesPrivate as Boolean) as Void
            m.private.allAttributesPrivate = launchDarklyParamAllAttributesPrivate
        end function,

        setEventsCapacity: function(launchDarklyParamCapacity as Integer) as Void
            m.private.eventsCapacity = launchDarklyParamCapacity
        end function,

        setEventsFlushIntervalSeconds: function(launchDarklyParamIntervalSeconds as Integer) as Void
            m.private.eventsFlushIntervalSeconds = launchDarklyParamIntervalSeconds
        end function,

        setLogger: function(launchDarklyParamNewLogger as Object) as Void
            m.private.logger = launchDarklyParamNewLogger
        end function,

        setLoggerNode: function(launchDarklyParamLoggerNode as Dynamic) as Void
            m.private.loggerNode = launchDarklyParamLoggerNode
        end function,

        setStoreBackend: function(launchDarklyParamNewStoreBackend as Object) as Void
            m.private.storeBackend = launchDarklyParamNewStoreBackend
        end function,

        setStoreBackendNode: function(launchDarklyParamStoreBackendNode as Dynamic) as Void
            m.private.storeBackendNode = launchDarklyParamStoreBackendNode
        end function,

        setStreaming: function(launchDarklyParamShouldStream as Boolean) as Void
            m.private.streaming = launchDarklyParamShouldStream
        end function,

        setLogLevel: function(launchDarklyParamLogLevel as Integer) as Void
            m.private.logLevel = launchDarklyParamLogLevel
        end function,

        setUseEvaluationReasons: function(launchDarklyParamUseReasons as Boolean) as Void
            m.private.useReasons = launchDarklyParamUseReasons
        end function,

        ' Application metadata may be used in LaunchDarkly analytics or other
        ' product features, but does not affect feature flag evaluations.
        setApplicationInfoValue: function(name as String, value as String) as Void
          if name <> "id" and name <> "version" then
            m.private.logger.warn("application info values can only be set for id and version at this time")
            return
          end if

          if Len(value) > 64 then
            m.private.logger.warn("application value " + value + " was longer than 64 characters and was discard")
            return
          end if

          if m.private.appInfoRegex.isMatch(value) then
            m.private.logger.warn("application value " + value + " contained invalid characters and was discarded")
            return
          end if

          if m.private.applicationInfo = invalid then
            m.private.applicationInfo = {}
          end if
          m.private.applicationInfo[name] = value
        end function
    }

    launchDarklyLocalThis.private.logger = LaunchDarklyLogger(launchDarklyLocalThis, LaunchDarklyLoggerPrint())

    return launchDarklyLocalThis
end function
