function LaunchDarklyBackoff() as Object
    return {
        private: {
            u: LaunchDarklyUtility(),
            attempts: 0,
            waitUntil: 0,
            streamStarted: createObject("roTimeSpan"),
            gotStreamData: false
        },

        started: function() as Void
            m.private.streamStarted.mark()
            m.private.gotStreamData = false
        end function,

        gotStreamData: function() as Void
            m.private.gotStreamData = true
        end function,

        reset: function() as Void
            m.private.attempts = 0
            m.private.waitUntil = 0
        end function,

        finished: function() as Void
            if m.private.gotStreamData AND m.private.streamStarted.totalSeconds() > 60 then
                m.reset()
                return
            end if

            m.private.attempts++

            if m.private.attempts = 1 then
                m.private.waitUntil = 1000 + m.private.u.getMilliseconds()
                return
            end if

            launchDarklyLocalBackoff = 1000 * (2 ^ m.private.attempts) / 2
            launchDarklyLocalBackoff /= 2
            REM jitter random value between 0 and backoff
            launchDarklyLocalBackoff += rnd(launchDarklyLocalBackoff)

            launchDarklyLocalBackoffLimit = 30 * 1000
            if launchDarklyLocalBackoff > launchDarklyLocalBackoffLimit then
                launchDarklyLocalBackoff = launchdarklyLocalBackoffLimit
            end if

            m.private.waitUntil = launchDarklyLocalBackoff + m.private.u.getMilliseconds()
        end function,

        shouldWait: function() as Boolean
            return m.private.waitUntil > m.private.u.getMilliseconds()
        end function
    }
end function

function LaunchDarklyStream(launchDarklyParamBuffer=invalid as Object) as Object
    launchDarklyLocalThis = {
        offset: 0,
        buffer: invalid,

        util: LaunchDarklyUtility(),

        count: function() as Integer
            return m.buffer.count() - m.offset
        end function,

        addBytes: function(launchDarklyParamBytes as Object) as Void
            m.buffer.append(launchDarklyParamBytes)
        end function,

        takeCount: function(launchDarklyParamCount as Integer) as Object
            if m.count() < launchDarklyParamCount then
                return invalid
            end if

            launchDarklyLocalResult = createObject("roByteArray")
            launchDarklyLocalResult.setResize(launchDarklyParamCount, true)

            m.util.memcpy(m.buffer, m.offset, launchDarklyLocalResult, 0, launchDarklyParamCount)
            m.offset += launchDarklyParamCount

            return launchDarklyLocalResult
        end function,

        REM Invalid or Integer
        takeByte: function() as Dynamic
            if m.count() = 0 then
                return invalid
            end if

            launchDarklyLocalResult = m.buffer[m.offset]
            m.offset += 1

            return launchDarklyLocalResult
        end function,

        skipCount: function(launchDarklyParamCount as Integer) as Object
            m.offset += launchDarklyParamCount
        end function

        takeUntilSequence: function(launchDarklyParamSequence as Object, launchDarklyParamIncludeSequence=false as Boolean) as Object
            for launchDarklyLocalX = m.offset to m.buffer.count() - 1 step + 1
                if m.buffer[launchDarklyLocalX] = launchDarklyParamSequence[0] then
                    launchDarklyLocalMatch = true

                    for launchDarklyLocalY = 1 to launchDarklyParamSequence.count() - 1 step + 1
                        if m.buffer[launchDarklyLocalX + launchDarklyLocalY] <> launchDarklyParamSequence[launchDarklyLocalY] then
                            launchDarklyLocalMatch = false
                            exit for
                        end if
                    end for

                    if launchDarklyLocalMatch = true then
                        launchDarklyLocalPrefix = m.takeCount(launchDarklyLocalX - m.offset)
                        m.offset += launchDarklyParamSequence.count()

                        if launchDarklyParamIncludeSequence = true then
                            launchDarklyLocalPrefix.append(launchDarklyParamSequence)
                        end if

                        return launchDarklyLocalPrefix
                    end if
                end if
            end for

            return invalid
        end function,

        shrink: function() as Void
            launchDarklyLocalRemainingCount = m.buffer.count() - m.offset

            launchDarklyLocalRemaining = createObject("roByteArray")
            launchDarklyLocalRemaining.setResize(launchDarklyLocalRemainingCount, true)

            m.util.memcpy(m.buffer, m.offset, launchDarklyLocalRemaining, 0, launchDarklyLocalRemainingCount)
            m.buffer = launchDarklyLocalRemaining
            m.offset = 0
        end function
    }

    if launchDarklyParamBuffer <> invalid then
        launchDarklyLocalThis.buffer = launchDarklyParamBuffer
    else
        launchDarklyLocalThis.buffer = createObject("roByteArray")
    end if

    return launchDarklyLocalThis
end function

function LaunchDarklyUtility() as Object
    return {
        memcpy: function(launchDarklyParamSource as Object, launchDarklyParamSourceOffset as Integer, launchDarklyParamDestination as Object, launchDarklyParamDestinationOffset as Integer, launchDarklyParamCount as Integer) as Void
            for launchDarklyLocalI = 0 to launchDarklyParamCount - 1 step + 1
                launchDarklyParamDestination.setEntry(launchDarklyParamDestinationOffset + launchDarklyLocalI, launchDarklyParamSource.getEntry(launchDarklyParamSourceOffset + launchDarklyLocalI))
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

        isNaturalASCIIByte: function(launchDarklyParamByte as Integer) as Boolean
            return launchDarklyParamByte >= 48 AND launchDarklyParamByte <= 57
        end function,

        convertASCIIByteToInteger: function(launchDarklyParamByte as Integer) as Integer
            return launchDarklyParamByte - 48
        end function,

        isNatural: function(launchDarklyParamBuffer as Object) as Boolean
            for each launchDarklyLocalChar in launchDarklyParamBuffer
                if not m.isNaturalASCIIByte(launchDarklyLocalChar)
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

        unsignedIntegerToLittleEndian: function(launchDarklyParamNumber as Integer) as Object
            launchDarklyLocalBytes = createObject("roByteArray")
            launchDarklyLocalBytes[3] = 0

            for launchDarklyLocalX = 0 to launchDarklyLocalBytes.count() - 1 step + 1
                launchDarklyLocalBytes[launchDarklyLocalX] = (launchDarklyParamNumber >> (8 * launchDarklyLocalX)) and 255
            end for

            return launchDarklyLocalBytes
        end function,

        randomBytes: function(launchDarklyParamCount as Integer) as Object
            launchDarklyLocalBytes = createObject("roByteArray")
            launchDarklyLocalBytes[launchDarklyParamCount - 1] = 0

            for launchDarklyLocalX = 0 to launchDarklyLocalBytes.count() - 1 step + 1
                launchDarklyLocalBytes[launchDarklyLocalX] = rnd(256)
            end for

            return launchDarklyLocalBytes
        end function,

        byteArrayEq: function(launchDarklyParamLeft as Object, launchDarklyParamRight as Object) as Boolean
            if launchDarklyParamLeft.count() <> launchDarklyParamRight.count() then
                return false
            end if

            for launchDarklyLocalX = 0 to launchDarklyParamLeft.count() - 1 step + 1
                if launchDarklyParamLeft.getEntry(launchDarklyLocalX) <> launchDarklyParamRight.getEntry(launchDarklyLocalX) then
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

        prepareNetworkingCommon: function(launchDarklyParamMessagePort as Object, launchDarklyParamConfig as Object, launchDarklyParamTransfer as Object, headers as Object) as Void
            launchDarklyParamTransfer.setPort(launchDarklyParamMessagePort)
            launchDarklyParamTransfer.setHeaders(m.addDefaultHeaders(headers, launchDarklyParamConfig))
            launchDarklyParamTransfer.setCertificatesFile("common:/certs/ca-bundle.crt")
            launchDarklyParamTransfer.initClientCertificates()
        end function,

        addDefaultHeaders: function(headers as Object, launchDarklyParamConfig as Object) as Object
            headers["User-Agent"] = "RokuClient/" + LaunchDarklySDKVersion()
            headers["Authorization"] = launchDarklyParamConfig.private.mobileKey

            appInfoHeader = m.createApplicationInfoHeader(launchDarklyParamConfig)
            if appInfoHeader <> "" then
              headers["X-LaunchDarkly-Tags"] = appInfoHeader
            end if

            return headers
        end function

        ' When given the LaunchDarkly configuration object, generate the appropriate X-LaunchDarkly-Tags header value.
        '
        ' This method will return an empty string if no valid application info values have been set on the config;
        ' otherwise, it will return the formatted header value.
        createApplicationInfoHeader: function(config as Object) as String
          if config.private.applicationInfo = invalid then
            return ""
          end if

          ' NOTE: The spec calls for tags to be in sorted order by tag name.
          ' Additional tags added should maintain this ordering.
          values = CreateObject("roArray", 2, false)
          if config.private.applicationInfo["id"] <> invalid then
            values.push("application-id/" + config.private.applicationInfo["id"])
          end if

          if config.private.applicationInfo["version"] <> invalid then
            values.push("application-version/" + config.private.applicationInfo["version"])
          end if

          return values.Join(" ")
        end function,

        stripHTTPProtocol: function(launchDarklyParamRawURI as String) as String
            launchDarklyLocalHTTPS = "https://"
            launchDarklyLocalHTTP = "http://"

            if left(launchDarklyParamRawURI, len(launchDarklyLocalHTTPS)) = launchdarklyLocalHTTPS then
                return mid(launchDarklyParamRawURI, len(launchDarklyLocalHTTPS) + 1)
            else if left(launchDarklyParamRawURI, len(launchDarklyLocalHTTP)) = launchDarklyLocalHTTP then
                return mid(launchDarklyParamRawURI, len(launchDarklyLocalHTTP) + 1)
            else
                REM impossible in usage
                return ""
            end if
        end function,

        ' Provides a simplistic approach at parsing out the bits of a URI.
        '
        ' WARNING: This does not support IPv6.
        '
        ' This function assumes the provided URI is well-formed. It will return
        ' an object containing:
        '
        ' - host
        ' - port :: If not provided, defaults to 80 for http and 443 for https
        ' - path :: URL path without a trailing slash. A path of "/" is returned as ""
        ' - scheme :: e.g. http or https. Defaults to http
        extractUriParts: function(uri as String) as Object
            parts = { scheme: "http", port: 80, path: "" }

            launchDarklyLocalHTTPS = "https://"
            launchDarklyLocalHTTP = "http://"

            withoutScheme = uri
            if left(uri, len(launchDarklyLocalHTTPS)) = launchdarklyLocalHTTPS then
                parts["scheme"] = "https"
                parts["port"] = 443
                withoutScheme = mid(uri, len(launchDarklyLocalHTTPS) + 1)
            else if left(uri, len(launchDarklyLocalHTTP)) = launchDarklyLocalHTTP then
                parts["scheme"] = "http"
                parts["port"] = 80
                withoutScheme = mid(uri, len(launchDarklyLocalHTTP) + 1)
            end if

            slashIndex = withoutScheme.Instr("/")
            questionIndex = withoutScheme.Instr("?")

            if questionIndex < slashIndex and questionIndex <> -1 then
              return invalid
            end if

            if slashIndex = -1 and questionIndex = -1 then
              parts["host"] = withoutScheme
            else if slashIndex <> -1 and questionIndex = -1 then
              parts["host"] = withoutScheme.Left(slashIndex)
              parts["path"] = withoutScheme.Mid(slashIndex)
            else if slashIndex <> -1 and questionIndex <> -1 then
              parts["host"] = withoutScheme.Left(slashIndex)
              parts["path"] = withoutScheme.Mid(slashIndex, questionIndex - slashIndex)
            else if slashIndex = -1 then
              parts["host"] = withoutScheme.Left(questionIndex)
            end if
            parts["path"] = m.trimTrailingSlash(parts["path"])

            hostParts = parts["host"].Split(":")
            if hostParts.Count() = 2 then
              parts["host"] = hostParts[0]
              parts["port"] = hostParts[1].ToInt()
            else if hostParts.Count() > 2 then
              return invalid
            end if

            return parts
        end function,

        trimTrailingSlash: function(input as String) as String
          while input.EndsWith("/")
            input = input.Left(input.Len() - 1)
          end while

          return input
        end function,

        deepCopy: function(launchDarklyParamValue as Dynamic) as Dynamic
            return parseJSON(formatJSON(launchDarklyParamValue))
        end function,

        contextKindForUser: function(launchDarklyParamUser as Object) as String
            if launchDarklyParamUser.private.anonymous = true then
                return "anonymousUser"
            end if
            return "user"
        end function
    }
end function
