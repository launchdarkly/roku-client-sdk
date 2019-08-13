function LaunchDarklyBackoff() as Object
    return {
        private: {
            u: LaunchDarklyUtility(),
            attempts: 0,
            waitUntil: 0
        },
        fail: function() as Void
            m.private.attempts++

            launchDarklyLocalBackoff = 1000 * (2 ^ m.private.attempts) / 2
            launchDarklyLocalBackoffLimit = 3600 * 1000

            if launchDarklyLocalBackoff > launchDarklyLocalBackoffLimit then
                launchDarklyLocalBackoff = launchdarklyLocalBackoffLimit
            end if

            launchDarklyLocalBackoff /= 2

            REM jitter random value between 0 and backoff
            launchDarklyLocalBackoff += rnd(launchDarklyLocalBackoff)

            m.private.waitUntil = launchDarklyLocalBackoff + m.private.u.getMilliseconds()
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
        memcpy: function(launchDarklyParamSource as Object, launchDarklyParamSourceOffset as Integer, launchDarklyParamDestination as Object, launchDarklyParamDestinationOffset as Integer, launchDarklyParamCount as Integer) as Void
            for launchDarklyLocalI = 0 to launchDarklyParamCount - 1 step + 1
                destination.setEntry(launchDarklyParamDestinationOffset + launchDarklyLocalI, launchDarklyParamSource.getEntry(launchDarklyParamSourceOffset + launchDarklyLocalI))
            end for
        end function

        makeBytes: function(launchDarklyParamText as String) as Object
            launchDarklyLocalBytes = createObject("roByteArray")
            launchDarklyLocalBytes.fromAsciiString(launchDarklyParamText)
            return launchDarklyLocalBytes
        end function,

        regexHex: createObject("roRegex", "^[a-f0-9]+$", "i"),

        isValidHex: function(launchDarklyParamText as String) as Boolean
            return m.regexHex.isMatch(launchDarklyParamText)
        end function,

        REM Integer or Invalid
        hexToDecimal: function(launchDarklyParamHex as String) as Dynamic
            if m.isValidHex(launchDarklyParamHex) then
                return val(launchDarklyParamHex, 16)
            else
                return invalid
            end if
        end function

        isNatural: function(launchDarklyParamBuffer as Object) as Boolean
            for each launchDarklyLocalChar in launchDarklyParamBuffer
                if launchDarklyLocalChar < 48 OR launchDarklyLocalChar > 57 then
                    return false
                end if
            end for

            return launchDarklyParamBuffer.count() > 0
        end function,

        littleEndianUnsignedToInteger: function(launchDarklyParamBytes as Object) as Integer
            launchDarklyLocalCounter = 0
            launchDarklyLocalOutput = 0

            for launchDarklyLocalX = 0 to launchDarklyParamBytes.count() - 1 step + 1
                if launchDarklyLocalX = 0 then
                    launchDarklyLocalOutput = launchDarklyParamBytes.getEntry(launchDarklyLocalX)
                else
                    launchDarklyLocalOutput = launchDarklyLocalOutput + (launchDarklyParamBytes.getEntry(launchDarklyLocalX) * (2 ^ (launchDarklyLocalX * 8)))
                end if
            end for

            return launchDarklyLocalOutput
        end function,

        byteArrayEq: function(launchDarklyParamLeft as Object, launchDarklyParamRight as Object) as Boolean
            if launchDarklyParamLeft.count() <> launchDarklyParamRight.count() then
                return false
            end if

            for x = 0 to launchDarklyParamLeft.count() - 1 step + 1
                if launchDarklyParamLeft.getEntry(x) <> launchDarklyParamRight.getEntry(x) then
                    return false
                end if
            end for

            return true
        end function,

        getMilliseconds: function()
            REM Clock is stopped on object creation
            launchDarklyLocalNow = createObject("roDateTime")
            REM Ensure double is used
            launchDarklyLocalCreationDate# = launchDarklyLocalNow.asSeconds()
            launchDarklyLocalCreationDate# *= 1000
            launchDarklyLocalCreationDate# += launchDarklyLocalNow.getMilliseconds()
            return launchDarklyLocalCreationDate#
        end function,

        prepareNetworkingCommon: function(launchDarklyParamMessagePort as Object, launchDarklyParamConfig as Object, launchDarklyParamTransfer as Object) as Void
            launchDarklyParamTransfer.setPort(launchDarklyParamMessagePort)
            launchDarklyParamTransfer.addHeader("User-Agent", "RokuClient/" + launchDarklyParamConfig.private.sdkVersion)
            launchDarklyParamTransfer.addHeader("Authorization", launchDarklyParamConfig.private.mobileKey)
            launchDarklyParamTransfer.setCertificatesFile("common:/certs/ca-bundle.crt")
            launchDarklyParamTransfer.initClientCertificates()
        end function,

        stripHTTPProtocol: function(launchDarklyParamRawURI as String) as String
            launchDarklyLocalHTTPS = "https://"
            launchDarklyLocalHTTP = "http://"

            if left(launchDarklyParamRawURI, len(launchDarklyLocalHTTPS)) = launchdarklyLocalHTTPS then
                return mid(launchDarklyParamRawURI, len(launchDarklyLocalHTTPS) + 1)
            else if left(launchDarklyParamRawURI, len(launchDarklyLocalHTTP)) = http then
                return mid(launchDarklyParamRawURI, len(launchDarklyLocalHTTP) + 1)
            else
                REM impossible in usage
                return ""
            end if
        end function
    }
end function
