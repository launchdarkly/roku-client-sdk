function LaunchDarklySGInit(launchDarklyParamConfig as Object, context as Object) as Void
    REM ensure we don't call identify for this context
    context.private.initial = true
    launchDarklyLocalNode = launchDarklyParamConfig.private.sceneGraphNode
    launchDarklyLocalNode.context = context
    launchDarklyLocalNode.config = launchDarklyParamConfig
end function

function LaunchDarklySG(launchDarklyParamClientNode as Dynamic) as Object
    launchDarklyLocalLoggerBackend = LaunchDarklyLoggerSG(launchDarklyParamClientNode.config.private.loggerNode)
    launchDarklyLocalLogger = LaunchDarklyLogger(launchDarklyParamClientNode.config, launchDarklyLocalLoggerBackend)

    launchDarklyLocalThis = {
        private: {
            clientNode: launchDarklyParamClientNode,
            logger: launchDarklyLocalLogger,
            offline: launchDarklyParamClientNode.config.private.offline,
            storeNode: launchDarklyParamClientNode.config.private.storeBackendNode,
            store: LaunchDarklyStoreSG(launchDarklyParamClientNode.config.private.storeBackendNode),

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

        identify: function(context as Object) as Void
            m.status.private.setStatus(m.status.map.uninitialized)
            m.private.clientNode.context = context
        end function,

        track: function(launchDarklyParamKey as String, launchDarklyParamData=invalid as Object, launchDarklyParamMetric=invalid as Dynamic) as Void
            m.private.clientNode.track = {
                key: launchDarklyParamKey,
                data: launchDarklyParamData,
                metric: launchDarklyParamMetric
            }
        end function
    }

    launchDarklyLocalThis.append(LaunchDarklyClientSharedFunctions(launchDarklyParamClientNode))

    return launchDarklyLocalThis
end function
