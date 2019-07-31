function LaunchDarklySGInit(config as Object, user as Object) as Void
    node = config.private.sceneGraphNode
    node.user = user
    node.config = config
end function

function LaunchDarklySG(clientNode as Dynamic) as Object
    loggerBackend = LaunchDarklyLoggerSG(clientNode.config.private.loggerNode)
    logger = LaunchDarklyLogger(clientNode.config, loggerBackend)

    this = {
        private: {
            clientNode: clientNode,
            logger: logger,
            offline: clientNode.config.private.offline,
            storeNode: clientNode.config.private.storeBackendNode,

            isOffline: function() as Boolean
                return m.offline
            end function,

            handleEventsForEval: function(bundle as Object) as Void
                m.clientNode.event = bundle
            end function,

            lookupFlag: function(flagKey as String) as Object
                return m.storeNode.flags.lookup(flagKey)
            end function,

            lookupAll: function() as Object
                return m.storeNode.flags
            end function
        },

        flush: function() as Void
            m.private.clientNode.flush = true
        end function,

        identify: function(user as Object) as Void
            m.private.clientNode.user = user
        end function,

        track: function(key as String, data=invalid as Object) as Void
            m.private.clientNode.track = {
                key: key,
                data: data
            }
        end function,

        allFlags: function() as Object
            return m.private.storeNode.flags
        end function
    }

    this.append(LaunchDarklyClientSharedFunctions())

    return this
end function
