function LaunchDarklySSE() as Object
    return {
        private: {
            lineBuffer: "",
            eventName: "",
            eventBuffer: "",

            processField: function(field as String, value as String) as Void
                if Left(value, 1) = chr(32) then
                    value = Mid(value, 2)
                end if

                if field = "event" then
                    m.eventName = value
                else if field = "data" then
                    if m.eventBuffer.len() <> 0 then
                        m.eventBuffer = m.eventBuffer + chr(10)
                    end if

                    m.eventBuffer = m.eventBuffer + value
                else
                    REM unknown field
                end if
            end function,

            parseLine: function(line as String) as Object
                if line.len() = 0 then
                    event = invalid

                    if m.eventBuffer <> "" then
                        event = {
                            name: m.eventName,
                            value: m.eventBuffer
                        }
                    end if

                    m.eventName = ""
                    m.eventBuffer = ""

                    return event
                else
                    colonPosition = Instr(1, line, chr(58))

                    if colonPosition = 1 then
                        REM comment
                    else if colonPosition = 0 then
                        m.processField(line, "")
                    else
                        field = Left(line, colonPosition - 1)

                        value = Mid(line, colonPosition + 1)

                        m.processField(field, value)
                    end if

                    return invalid
                end if
            end function
        },

        addChunk: function(chunk as String) as Void
            m.private.lineBuffer = m.private.lineBuffer + chunk
        end function,

        consumeEvent: function() as Object
            while true
                lineEndPosition = Instr(1, m.private.lineBuffer, chr(10))

                if lineEndPosition = 0 then
                    return invalid
                end if

                line = Left(m.private.lineBuffer, lineEndPosition - 1)

                result = m.private.parseLine(line)

                m.private.lineBuffer = Mid(m.private.lineBuffer, lineEndPosition + 1)

                if result <> invalid then
                    return result
                end if
            end while
        end function
    }
end function
