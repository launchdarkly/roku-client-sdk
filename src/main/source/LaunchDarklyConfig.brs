function LaunchDarklyConfig(mobileKey as String) as Object
    return {
        private: {
            appURI: "https://app.launchdarkly.com",
            eventsURI: "https://mobile.launchdarkly.com",
            pollingIntervalSeconds: 15,
            mobileKey: mobileKey,
            offline: false,
            privateAttributeNames: {},
            allAttributesPrivate: false,
            eventsCapacity: 100,
            eventsFlushIntervalSeconds: 30
        },
        setAppURI: function(appURI as String) as Void
            m.private.appURI = appURI
        end function,
        setEventsURI: function(eventsURI as String) as Void
            m.private.eventsURI = eventsURI
        end function,
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
        end function
    }
end function
