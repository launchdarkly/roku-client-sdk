function LaunchDarklyConfig(mobileKey as String) as Object
    return {
        private: {
            appURI: "https://app.launchdarkly.com",
            pollingInterval: 15,
            mobileKey: mobileKey
        },
        setAppURI: function(appURI as String) as Void
            m.private.appURI = appURI
        end function,
        setPollingInterval: function(pollingInterval as Integer) as Void
            m.private.pollingInterval = pollingInterval
        end function
    }
end function
