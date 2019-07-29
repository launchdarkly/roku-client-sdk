function LaunchDarklyLoggerSG(node) as Object
    return {
        private: {
            node: node
        }
        log: function(level as Integer, message as String)
            m.private.node.log = {
                level: level,
                message: message
            }
        end function
    }
end function

function LaunchDarklyLoggerPrint() as Object
    return {
        private: {
            levelToString: function(level as Integer) as String
                if level = 1 then
                    return "Error"
                else if level = 2 then
                    return "Warn"
                else if level = 3 then
                    return "Info"
                else if level = 4 then
                    return "Debug"
                else
                    return invalid
                end if
            end function
        },

        log: function(level as Integer, message as String)
            now = CreateObject("roDateTime").asSeconds()
            print "[LaunchDarkly, " m.private.levelToString(level) "," now "] " message
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

function LaunchDarklyLogger(config as Object, backend=invalid as Object) as Object
    return {
        private: {
            logLevel: config.private.logLevel,
            backend: backend,
            levels: LaunchDarklyLogLevels(),

            maybeLog: function(level as Integer, message as String) as Void
                if m.backend <> invalid AND level <= m.logLevel then
                    m.backend.log(level, message)
                end if
            end function
        },

        error: function(message as String) as Void
            m.private.maybeLog(m.private.levels.error, message)
        end function,

        warn: function(message as String) as Void
            m.private.maybeLog(m.private.levels.warn, message)
        end function,

        info: function(message as String) as Void
            m.private.maybeLog(m.private.levels.info, message)
        end function,

        debug: function(message as String) as Void
            m.private.maybeLog(m.private.levels.debug, message)
        end function
    }
end function
