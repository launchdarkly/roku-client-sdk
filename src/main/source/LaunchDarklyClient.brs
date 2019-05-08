function LaunchDarklyClient(config as Object, user as Object, port as Object) as Object
    return {
        private: {
            user: user,
            config: config,
            port: port
        },
        variation: function(flagKey as String, fallback as Dynamic) as Dynamic
            if m.private.config.private.offline then
                return fallback
            end if
        end function
    }
end function
