function LaunchDarklySGInit(launchDarklyParamConfig as Object, launchDarklyParamUser as Object) as Void
    launchDarklyLocalNode = config.private.sceneGraphNode
    launchDarklyLocalNode.user = launchDarklyParamUser
    launchDarklyLocalNode.config = launchDarklyParamConfig
end function

function LaunchDarklySG(launchDarklyParamClientNode as Dynamic) as Object
    launchDarklyLocalLoggerBackend = LaunchDarklyLoggerSG(launchDarklyParamClientNode.config.private.loggerNode)
    launchDarklyLocalLogger = LaunchDarklyLogger(launchDarklyParamClientNode.config, launchDarklyLocalLoggerBackend)

    launchDarklyLocalThis = {
        private: {
            clientNode: launchDarklpParamClientNode,
            logger: launchDarklyLocalLogger,
            offline: launchDarklyParamClientNode.config.private.offline,
            storeNode: launchDarklyParamClientNode.config.private.storeBackendNode,

            isOffline: function() as Boolean
                return m.offline
            end function,

            handleEventsForEval: function(launchDarklyParamBundle as Object) as Void
                m.clientNode.event = launchDarklyParamBundle
            end function,

            lookupFlag: function(launchDarklyParamFlagKey as String) as Object
                return m.storeNode.flags.lookup(launchDarklyParamFlagKey)
            end function,

            lookupAll: function() as Object
                return m.storeNode.flags
            end function
        },

        flush: function() as Void
            m.private.clientNode.flush = true
        end function,

        identify: function(launchDarklyParamUser as Object) as Void
            m.private.clientNode.user = launchDarklyParamUser
        end function,

        track: function(launchDarklyParamKey as String, launchDarklyParamData=invalid as Object) as Void
            m.private.clientNode.track = {
                key: launchDarklyParamKey,
                data: launchDarklyParamData
            }
        end function,

        allFlags: function() as Object
            return m.private.storeNode.flags
        end function
    }

    launchDarklyLocalThis.append(LaunchDarklyClientSharedFunctions())

    return launchDarklyLocalThis
end function
