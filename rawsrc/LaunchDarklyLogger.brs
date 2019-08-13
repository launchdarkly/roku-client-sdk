function LaunchDarklyLoggerSG(launchDarklyParamNode) as Object
    return {
        private: {
            node: launchDarklyParamNode
        }
        log: function(launchDarklyParamLevel as Integer, launchDarklyParamMessage as String)
            m.private.node.log = {
                level: launchDarklyParamLevel,
                message: launchDarklyParamMessage
            }
        end function
    }
end function

function LaunchDarklyLoggerPrint() as Object
    return {
        private: {
            levelToString: function(launchDarklyParamLevel as Integer) as String
                if launchDarklyParamLevel = 1 then
                    return "Error"
                else if launchDarklyParamLevel = 2 then
                    return "Warn"
                else if launchDarklyParamLevel = 3 then
                    return "Info"
                else if launchDarklyParamLevel = 4 then
                    return "Debug"
                else
                    return invalid
                end if
            end function
        },

        log: function(launchDarklyParamLevel as Integer, launchDarklyParamMessage as String)
            launchDarklyLocalNow = createObject("roDateTime").asSeconds()
            print "[LaunchDarkly, " m.private.levelToString(launchDarklyParamLevel) "," launchDarklyLocalNow "] " launchDarklyParamMessage
        end function
    }
end function

function LaunchDarklyLogLevels() as Object
    return {
        none: 0,
        error: 1,
        warn: 2,
        info: 3,
        debug: 4
    }
end function

function LaunchDarklyLogger(launchDarklyParamConfig as Object, launchDarklyParamBackend=invalid as Object) as Object
    return {
        private: {
            logLevel: config.private.logLevel,
            backend: launchDarklyParamBackend,
            levels: LaunchDarklyLogLevels(),

            maybeLog: function(launchDarklyParamLevel as Integer, launchDarklyParamMessage as String) as Void
                if m.backend <> invalid AND launchDarklyParamLevel <= m.logLevel then
                    m.backend.log(launchDarklyParamLevel, launchDarklyParamMessage)
                end if
            end function
        },

        error: function(launchDarklyParamMessage as String) as Void
            m.private.maybeLog(m.private.levels.error, launchDarklyParamMessage)
        end function,

        warn: function(launchDarklyParamMessage as String) as Void
            m.private.maybeLog(m.private.levels.warn, launchDarklyParamMessage)
        end function,

        info: function(launchDarklyParamMessage as String) as Void
            m.private.maybeLog(m.private.levels.info, launchDarklyParamMessage)
        end function,

        debug: function(launchDarklyParamMessage as String) as Void
            m.private.maybeLog(m.private.levels.debug, launchDarklyParamMessage)
        end function
    }
end function
