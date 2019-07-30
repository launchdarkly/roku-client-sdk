function LaunchDarklyConfig(mobileKey as String, sceneGraphNode=invalid as Dynamic) as Object
    this = {
        private: {
            appURI: "https://app.launchdarkly.com",
            eventsURI: "https://mobile.launchdarkly.com",
            streamURI: "https://clientstream.launchdarkly.com",
            pollingIntervalSeconds: 15,
            mobileKey: mobileKey,
            offline: false,
            privateAttributeNames: {},
            allAttributesPrivate: false,
            eventsCapacity: 100,
            eventsFlushIntervalSeconds: 30,
            logger: invalid,
            loggerNode: sceneGraphNode,
            storeBackend: invalid,
            storeBackendNode: sceneGraphNode,
            streaming: true,
            sdkVersion: "1.0.0-beta.1",
            logLevel: LaunchDarklyLogLevels().warn,
            sceneGraphNode: sceneGraphNode,

            validateURI: function(rawURI as String) as Boolean
                https = "https://"
                http = "http://"

                return left(rawURI, len(https)) = https OR left(rawURI, len(http)) = http
            end function
        },

        setAppURI: function(appURI as String) as Boolean
            if m.private.validateURI(appURI) then
                m.private.appURI = appURI

                return true
            else
                return false
            end if
        end function,

        setEventsURI: function(eventsURI as String) as Boolean
            if m.private.validateURI(eventsURI) then
                m.private.eventsURI = eventsURI

                return true
            else
                return false
            end if
        end function,

        setStreamURI: function(streamURI as String) as Boolean
            if m.private.validateURI(streamURI) then
                m.private.streamURI = streamURI

                return true
            else
                return false
            end if
        end function

        setPollingIntervalSeconds: function(pollingIntervalSeconds as Integer) as Void
            m.private.pollingIntervalSeconds = pollingIntervalSeconds
        end function,

        setOffline: function(offline as Boolean) as Void
            m.private.offline = offline
        end function,

        addPrivateAttribute: function(privateAttribute as String) as Void
            m.private.privateAttributeNames.addReplace(privateAttribute, 1)
        end function,

        setAllAttributesPrivate: function(allAttributesPrivate as Boolean) as Void
            m.private.allAttributesPrivate = allAttributesPrivate
        end function,

        setEventsCapacity: function(capacity as Integer) as Void
            m.private.eventsCapacity = capacity
        end function,

        setEventsFlushIntervalSeconds: function(intervalSeconds as Integer) as Void
            m.private.eventsFlushIntervalSeconds = intervalSeconds
        end function,

        setLogger: function(newLogger as Object) as Void
            m.private.logger = newLogger
        end function,

        setLoggerNode: function(loggerNode as Dynamic) as Void
            m.private.loggerNode = loggerNode
        end function,

        setStoreBackend: function(newStoreBackend as Object) as Void
            m.private.storeBackend = newStoreBackend
        end function,

        setStoreBackendNode: function(storeBackendNode as Dynamic) as Void
            m.private.storeBackendNode = storeBackendNode
        end function,

        setStreaming: function(shouldStream as Boolean) as Void
            m.private.streaming = shouldStream
        end function,

        setLogLevel: function(logLevel as Integer) as Void
            m.private.logLevel = logLevel
        end function
    }

    this.private.logger = LaunchDarklyLogger(this, LaunchDarklyLoggerPrint())

    return this
end function
