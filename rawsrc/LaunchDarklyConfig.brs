function LaunchDarklyConfig(launchDarklyParamMobileKey as String, launchDarklyParamSceneGraphNode=invalid as Dynamic) as Object
    launchDarklyLocalThis = {
        private: {
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
            sdkVersion: "1.0.0-beta.2",
            logLevel: LaunchDarklyLogLevels().warn,
            sceneGraphNode: launchDarklyParamSceneGraphNode,

            validateURI: function(launchDarklyParamRawURI as String) as Boolean
                launchDarklyLocalHTTPS = "https://"
                launchDarklyLocalHTTP = "http://"

                return left(launchDarklyParamRawURI, len(launchDarklyLocalHTTPS)) = launchDarklyLocalHTTPS OR left(launchDarklyParamRawURI, len(launchDarklyLocalHTTP)) = launchDarklyLocalHTTP
            end function
        },

        setAppURI: function(launchDarklyParamAppURI as String) as Boolean
            if m.private.validateURI(launchDarklyParamAppURI) then
                m.private.appURI = launchDarklyParamAppURI

                return true
            else
                return false
            end if
        end function,

        setEventsURI: function(launchDarklyParamEventsURI as String) as Boolean
            if m.private.validateURI(launchDarklyParamEventsURI) then
                m.private.eventsURI = launchDarklyParamEventsURI

                return true
            else
                return false
            end if
        end function,

        setStreamURI: function(launchDarklyParamStreamURI as String) as Boolean
            if m.private.validateURI(launchDarklyParamStreamURI) then
                m.private.streamURI = launchDarklyParamStreamURI

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
        end function
    }

    launchDarklyLocalThis.private.logger = LaunchDarklyLogger(launchDarklyLocalThis, LaunchDarklyLoggerPrint())

    return launchDarklyLocalThis
end function
