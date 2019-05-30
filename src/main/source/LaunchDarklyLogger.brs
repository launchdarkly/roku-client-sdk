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

function LaunchDarklyLogger(backend=invalid as Object) as Object
    return {
        private: {
            logLevel: 2,
            backend: backend,

            maybeLog: function(level as Integer, message as String) as Void
                if m.backend <> invalid AND level <= m.logLevel then
                    m.backend.log(level, message)
                end if
            end function
        },
        levels: {
            none: 0,
            error: 1,
            warn: 2,
            info: 3,
            debug: 4
        },

        setLogLevel: function(level as Integer) as Void
            m.private.logLevel = level
        end function,

        error: function(message as String) as Void
            m.private.maybeLog(m.levels.error, message)
        end function,

        warn: function(message as String) as Void
            m.private.maybeLog(m.levels.warn, message)
        end function,

        info: function(message as String) as Void
            m.private.maybeLog(m.levels.info, message)
        end function,

        debug: function(message as String) as Void
            m.private.maybeLog(m.levels.debug, message)
        end function
    }
end function
