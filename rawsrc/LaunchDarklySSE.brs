function LaunchDarklySSE() as Object
    return {
        private: {
            lineBuffer: "",
            eventName: "",
            eventBuffer: "",

            processField: function(launchDarklyParamField as String, launchDarklyParamValue as String) as Void
                if left(launchDarklyParamValue, 1) = chr(32) then
                    launchDarklyParamValue = mid(launchDarklyParamValue, 2)
                end if

                if launchDarklyParamField = "event" then
                    m.eventName = launchDarklyParamValue
                else if launchDarklyParamField = "data" then
                    if m.eventBuffer.len() <> 0 then
                        m.eventBuffer = m.eventBuffer + chr(10)
                    end if

                    m.eventBuffer = m.eventBuffer + launchDarklyParamValue
                else
                    REM unknown field
                end if
            end function,

            parseLine: function(launchDarklyParamLine as String) as Object
                if launchDarklyParamLine.len() = 0 then
                    launchDarklyLocalEvent = invalid

                    if m.eventBuffer <> "" then
                        launchDarklyLocalEvent = {
                            name: m.eventName,
                            value: m.eventBuffer
                        }
                    end if

                    m.eventName = ""
                    m.eventBuffer = ""

                    return launchDarklyLocalEvent
                else
                    launchDarklyLocalColonPosition = instr(1, launchDarklyParamLine, chr(58))

                    if launchDarklyLocalColonPosition = 1 then
                        REM comment
                    else if launchDarklyLocalColonPosition = 0 then
                        m.processField(launchDarklyParamLine, "")
                    else
                        launchDarklyLocalField = left(launchDarklyParamLine, launchDarklyLocalColonPosition - 1)

                        launchDarklyLocalValue = mid(launchDarklyParamLine, launchDarklyLocalColonPosition + 1)

                        m.processField(launchDarklyLocalField, launchDarklyLocalValue)
                    end if

                    return invalid
                end if
            end function
        },

        addChunk: function(launchDarklyParamChunk as String) as Void
            m.private.lineBuffer = m.private.lineBuffer + launchDarklyParamChunk
        end function,

        consumeEvent: function() as Object
            while true
                launchDarklyLocalLineEndPosition = instr(1, m.private.lineBuffer, chr(10))

                if launchDarklyLocalLineEndPosition = 0 then
                    return invalid
                end if

                launchDarklyLocalLine = left(m.private.lineBuffer, launchDarklyLocalLineEndPosition - 1)

                launchDarklyLocalResult = m.private.parseLine(launchDarklyLocalLine)

                m.private.lineBuffer = mid(m.private.lineBuffer, launchDarklyLocalLineEndPosition + 1)

                if launchDarklyLocalResult <> invalid then
                    return launchDarklyLocalResult
                end if
            end while
        end function
    }
end function
