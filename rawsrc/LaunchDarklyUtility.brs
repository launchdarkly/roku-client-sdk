function LaunchDarklyBackoff() as Object
    return {
        private: {
            u: LaunchDarklyUtility(),
            attempts: 0,
            waitUntil: 0
        },
        fail: function() as Void
            m.private.attempts++

            backoff = 1000 * (2 ^ m.private.attempts) / 2
            backoffLimit = 3600 * 1000

            if backoff > backoffLimit then
                backoff = backoffLimit
            end if

            backoff /= 2

            REM jitter random value between 0 and backoff
            backoff += rnd(backoff)

            m.private.waitUntil = backoff + m.private.u.getMilliseconds()
        end function,
        success: function() as Void
            m.private.attempts = 0
            m.private.waitUntil = 0
        end function,
        shouldWait: function() as Boolean
            return m.private.waitUntil > m.private.u.getMilliseconds()
        end function
    }
end function

function LaunchDarklyStream(buffer=invalid as Object) as Object
    this = {
        offset: 0,
        buffer: invalid,

        util: LaunchDarklyUtility(),

        count: function() as Integer
            return m.buffer.count() - m.offset
        end function,

        addBytes: function(bytes as Object) as Void
            m.buffer.append(bytes)
        end function,

        takeCount: function(count as Integer) as Object
            result = createObject("roByteArray")
            result.setResize(count, true)

            m.util.memcpy(m.buffer, m.offset, result, 0, count)
            m.offset += count

            return result
        end function,

        skipCount: function(count as Integer) as Object
            m.offset += count
        end function

        takeUntilSequence: function(sequence as Object, includeSequence=false as Boolean) as Object
            for x = m.offset to m.buffer.count() - 1 step + 1
                if m.buffer[x] = sequence[0] then
                    match = true

                    for y = 1 to sequence.count() - 1 step + 1
                        if m.buffer[x + y] <> sequence[y] then
                            match = false
                            exit for
                        end if
                    end for

                    if match = true then
                        prefix = m.takeCount(x - m.offset)
                        m.offset += sequence.count()

                        if includeSequence = true then
                            prefix.append(sequence)
                        end if

                        return prefix
                    end if
                end if
            end for

            return invalid
        end function,

        shrink: function() as Void
            remaining = createObject("roByteArray")
            remainingCount = m.buffer.count() - m.offset
            remaining.setResize(remainingCount, true)
            m.util.memcpy(m.buffer, m.offset, remaining, 0, remainingCount)
            m.buffer = remaining
            m.offset = 0
        end function
    }

    if buffer <> invalid then
        this.buffer = buffer
    else
        this.buffer = createObject("roByteArray")
    end if

    return this
end function

function LaunchDarklyUtility() as Object
    return {
        memcpy: function(source as Object, sourceOffset as Integer, destination as Object, destinationOffset as Integer, count as Integer) as Void
            for i = 0 to count - 1 step + 1
                destination.setEntry(destinationOffset + i, source.getEntry(sourceOffset + i))
            end for
        end function

        makeBytes: function(text as String) as Object
            bytes = createObject("roByteArray")
            bytes.fromAsciiString(text)
            return bytes
        end function,

        regexHex: createObject("roRegex", "^[a-f0-9]+$", "i"),

        isValidHex: function(text as String) as Boolean
            return m.regexHex.isMatch(text)
        end function,

        REM Integer or Invalid
        hexToDecimal: function(hex as String) as Dynamic
            if m.isValidHex(hex) then
                return val(hex, 16)
            else
                return invalid
            end if
        end function

        isNatural: function(buffer as Object) as Boolean
            for each char in buffer
                if char < 48 OR char > 57 then
                    return false
                end if
            end for

            return buffer.count() > 0
        end function,

        littleEndianUnsignedToInteger: function(bytes as Object) as Integer
            counter = 0
            output = 0

            for x = 0 to bytes.count() - 1 step + 1
                if x = 0 then
                    output = bytes.getEntry(x)
                else
                    output = output + (bytes.getEntry(x) * (2 ^ (x * 8)))
                end if
            end for

            return output
        end function,

        byteArrayEq: function(left as Object, right as Object) as Boolean
            if left.count() <> right.count() then
                return false
            end if

            for x = 0 to left.count() - 1 step + 1
                if left.getEntry(x) <> right.getEntry(x) then
                    return false
                end if
            end for

            return true
        end function,

        getMilliseconds: function()
            REM Clock is stopped on object creation
            now = CreateObject("roDateTime")
            REM Ensure double is used
            creationDate# = now.asSeconds()
            creationDate# *= 1000
            creationDate# += now.getMilliseconds()
            return creationDate#
        end function,

        prepareNetworkingCommon: function(messagePort as Object, config as Object, transfer as Object) as Void
            transfer.setPort(messagePort)
            transfer.addHeader("User-Agent", "RokuClient/" + config.private.sdkVersion)
            transfer.addHeader("Authorization", config.private.mobileKey)
            transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
            transfer.InitClientCertificates()
        end function,

        stripHTTPProtocol: function(rawURI as String) as String
            https = "https://"
            http = "http://"

            if left(rawURI, len(https)) = https then
                return mid(rawURI, len(https) + 1)
            else if left(rawURI, len(http)) = http then
                return mid(rawURI, len(http) + 1)
            else
                REM impossible in usage
                return ""
            end if
        end function
    }
end function
