function LaunchDarklyConfig(mobileKey as String) as Object
    return {
        private: {
            appURI: "https://app.launchdarkly.com",
            pollingInterval: 15,
            mobileKey: mobileKey,
            offline: false,
            privateAttributeNames: {},
            allAttributesPrivate: false,
            eventsCapacity: 100,
            eventsFlushInterval: 30
        },
        setAppURI: function(appURI as String) as Void
            m.private.appURI = appURI
        end function,
        setPollingInterval: function(pollingInterval as Integer) as Void
            m.private.pollingInterval = pollingInterval
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
        setEventsFlushInterval: function(interval as Integer) as Void
            m.private.eventsFlushInterval = interval
        end function
    }
end function
