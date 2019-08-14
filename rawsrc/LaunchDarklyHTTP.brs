REM https://tools.ietf.org/html/rfc7230

function LaunchDarklyHTTPResponse() as Object
    launchDarklyLocalUtil = LaunchDarklyUtility()

    return {
        private: {
            stream: LaunchDarklyStream(),
            util: launchDarklyLocalUtil,

            maxHeaderSize: 8192,

            responseStatusMap: {
                headerPending: 0,
                bodyPending: 1,
                responseDone: 2,
                noHeaderFoundWithinMaxHeaderLength: -1,
                statusNotAValidNumber: -2,
                contentLengthAndTransferEncodingConflict: -3,
                contentLengthInvalidNumber: -4,
                chunkLengthInvalidHex: -5,
                statusCodeNot3Digits: -6,
                unknownTransferEncoding: -7,
                badVersionFormat: -8
            },

            bodyStreamTypeMap: {
                fixed: 1,
                chunked: 2,
                unknown: 3
            },

            colon: launchDarklyLocalUtil.makeBytes(":"),
            space: launchDarklyLocalUtil.makeBytes(" "),
            crlf: launchDarklyLocalUtil.makeBytes(chr(13) + chr(10)),
            crlfcrlf: launchDarklyLocalUtil.makeBytes(chr(13) + chr(10) + chr(13) + chr(10)),
            slash: launchDarklyLocalUtil.makeBytes("/"),
            period: launchDarklyLocalUtil.makeBytes("."),

            tryParseHeader: function(launchDarklyParamCtx as Object) as Integer
                launchDarklyLocalHeader = m.stream.takeUntilSequence(m.crlfcrlf, true)
                if launchDarklyLocalHeader = invalid then
                    if m.stream.count() > m.maxHeaderSize then
                        return m.responseStatusMap.noHeaderFoundWithinMaxHeaderLength
                    else
                        return 0
                    end if
                end if

                launchDarklyLocalHeaderStream = LaunchDarklyStream(launchDarklyLocalHeader)

                launchDarklyLocalStatusLine = launchDarklyLocalHeaderStream.takeUntilSequence(m.crlf, true)
                if launchDarklyLocalStatusLine = invalid then
                    return m.responseStatusMap.badVersionFormat
                end if

                launchDarklyLocalStatusLineStream = LaunchDarklyStream(launchDarklyLocalStatusLine)

                launchDarklyLocalResponseVersion = launchDarklyLocalStatusLineStream.takeUntilSequence(m.space, true)
                if launchDarklyLocalResponseVersion = invalid then
                    return m.responseStatusMap.badVersionFormat
                end if
                launchDarklyLocalResponseVersionStream = LaunchDarklyStream(launchDarklyLocalResponseVersion)

                launchDarklyLocalResponseVersionPrefix = launchDarklyLocalResponseVersionStream.takeUntilSequence(m.slash)
                if launchDarklyLocalResponseVersionPrefix = invalid OR launchDarklyLocalResponseVersionPrefix.toAsciiString() <> "HTTP" then
                    return m.responseStatusMap.badVersionFormat
                end if

                launchDarklyLocalMajorVersion = launchDarklyLocalResponseVersionStream.takeUntilSequence(m.period)
                if launchDarklyLocalMajorVersion = invalid OR m.util.isNatural(launchDarklyLocalMajorVersion) = false then
                    return m.responseStatusMap.badVersionFormat
                end if
                launchDarklyLocalMajorVersion = launchDarklyLocalMajorVersion.toAsciiString().toInt()

                launchDarklyLocalMinorVersion = launchDarklyLocalResponseVersionStream.takeUntilSequence(m.space)
                if launchDarklyLocalMinorversion = invalid OR m.util.isNatural(launchdarklyLocalMinorVersion) = false then
                    return m.responseStatusMap.badVersionFormat
                end if
                launchDarklyLocalMinorVersion = launchDarklyLocalMinorVersion.toAsciiString().toInt()

                launchDarklyLocalResponseCode = launchDarklyLocalStatusLineStream.takeUntilSequence(m.space)
                if m.util.isNatural(launchDarklyLocalResponseCode) then
                    if launchDarklyLocalResponseCode.count() = 3 then
                        launchDarklyLocalResponseCode = launchDarklyLocalResponseCode.toAsciiString().toInt()
                    else
                        return m.responseStatusMap.statusCodeNot3Digits
                    end if
                else
                    return m.responseStatusMap.statusNotAValidNumber
                end if

                launchDarklyLocalResponseMessage = launchDarklyLocalStatusLineStream.takeUntilSequence(m.crlf).toAsciiString()

                launchDarklyLocalResponseHeaders = {}
                while true
                    launchDarklyLocalHeaderField = launchDarklyLocalHeaderStream.takeUntilSequence(m.crlf, true)

                    if launchDarklyLocalHeaderField = invalid or launchDarklyLocalHeaderField.count() <= 2 then
                        exit while
                    end if
                    launchDarklyLocalHeaderFieldStream = LaunchDarklyStream(launchDarklyLocalHeaderField)

                    launchDarklyLocalFieldName = launchDarklyLocalHeaderFieldStream.takeUntilSequence(m.colon)
                    launchDarklyLocalFieldValue = launchDarklyLocalHeaderFieldStream.takeUntilSequence(m.crlf)

                    while launchDarklyLocalFieldValue.count() > 0 AND (launchDarklyLocalFieldValue[0] = 32 OR launchDarklyLocalFieldValue[0] = 0)
                        launchDarklyLocalFieldValue.shift()
                    end while

                    launchDarklyLocalResponseHeaders[lCase(launchDarklyLocalFieldName.toAsciiString())] = launchDarklyLocalFieldValue.toAsciiString()
                end while

                launchDarklyLocalContentLength = launchDarklyLocalResponseHeaders["content-length"]
                launchDarklyLocalTransferEncoding = launchDarklyLocalResponseHeaders["transfer-encoding"]

                if launchDarklyLocalContentLength <> invalid AND launchDarklyLocalTransferEncoding <> invalid then
                    return m.responseStatusMap.contentLengthAndTransferEncodingConflict
                end if

                if launchDarklyLocalContentLength <> invalid then
                    if m.util.isNatural(m.util.makeBytes(launchDarklyLocalContentLength)) then
                        m.bodyStreamType = m.bodyStreamTypeMap.fixed
                        m.remainingContentLength = launchDarklyLocalContentLength.toInt()
                    else
                        return m.responseStatusMap.contentLengthInvalidNumber
                    end if
                else
                    if launchDarklyLocalTransferEncoding <> invalid then
                        if launchDarklyLocalTransferEncoding = "chunked" then
                            m.bodyStreamType = m.bodyStreamTypeMap.chunked
                        else
                            return m.responseStatusMap.unknownTransferEncoding
                        end if
                    else
                        m.bodyStreamType = m.bodyStreamTypeMap.unknown
                    end if
                end if

                launchDarklyParamCtx.responseCode = launchDarklyLocalResponseCode
                launchDarklyParamCtx.responseMessage = launchDarklyLocalResponseMessage
                launchDarklyParamCtx.responseHeaders = launchDarklyLocalResponseHeaders
                launchDarklyParamCtx.responseMajorVersion = launchDarklyLocalMajorVersion
                launchDarklyParamCtx.responseMinorVersion = launchDarklyLocalMinorVersion

                return m.responseStatusMap.bodyPending
            end function,

            REM 1 = fixed size
            REM 2 = chunked
            REM 3 = unknown size
            bodyStreamType: invalid,
            REM when bodyStreamType = 1
            remainingContentLength: invalid,
            currentChunkSize: invalid,

            tryParseBody: function(launchDarklyParamCtx as Object) as Object
                launchDarklyLocalResponseBody = invalid

                if launchDarklyParamCtx.responseCode = 204 then
                    launchDarklyParamCtx.responseStatus = m.responseStatusMap.responseDone
                    return invalid
                else if m.bodyStreamType = m.bodyStreamTypeMap.unknown then
                    launchDarklyLocalAvailable = m.stream.count()

                    if launchDarklyLocalAvailable > 0 then
                        return m.stream.takeCount(launchDarklyLocalAvailable)
                    else
                        return invalid
                    end if
                else if m.bodyStreamType = m.bodyStreamTypeMap.fixed then
                    launchDarklyLocalAvailable = m.stream.count()

                    if launchdarklyLocalAvailable > m.remainingContentLength then
                        launchDarklyLocalAvailable = m.remainingContentLength
                    end if

                    launchDarklyLocalResponseBody = m.stream.takeCount(launchDarklyLocalAvailable)
                    m.remainingContentLength -= launchDarklyLocalAvailable

                    if m.remainingContentLength = 0 then
                        launchDarklyParamCtx.responseStatus = m.responseStatusMap.responseDone
                    end if
                else if m.bodyStreamType = m.bodyStreamTypeMap.chunked then
                    launchDarklyLocalResponseBody = createObject("roByteArray")

                    while true
                        if m.currentChunkSize = invalid then
                            launchDarklyLocalChunkSize = m.stream.takeUntilSequence(m.crlf)

                            if launchDarklyLocalChunkSize = invalid then
                                exit while
                            end if

                            launchDarklyLocalChunkSize = m.util.hexToDecimal(launchDarklyLocalChunkSize.toAsciiString())

                            if launchDarklyLocalChunkSize = invalid then
                                launchDarklyParamCtx.responseStatus = m.responseStatusMap.chunkLengthInvalidHex
                                return invalid
                            else if launchDarklyLocalChunkSize = 0 then
                                launchDarklyParamCtx.responseStatus = m.responseStatusMap.responseDone

                                exit while
                            end if

                            m.currentChunkSize = launchDarklyLocalChunkSize
                        end if

                        if m.stream.count() < m.currentChunkSize + 2 then
                            exit while
                        end if

                        launchDarklyLocalChunk = m.stream.takeCount(m.currentChunkSize)

                        m.stream.takeCount(2)

                        launchDarklyLocalResponseBody.append(launchDarklyLocalChunk)

                        m.currentChunkSize = invalid
                    end while
                end if

                if launchDarklyLocalResponseBody = invalid OR launchDarklyLocalResponseBody.count() = 0 then
                    return invalid
                else
                    return launchDarklyLocalResponseBody
                end if
            end function

            tryParseHTTP: function(launchDarklyParamCtx as Object) as Object
                if launchDarklyParamCtx.responseStatus = m.responseStatusMap.headerPending then
                    launchDarklyParamCtx.responseStatus = m.tryParseHeader(launchDarklyParamCtx)
                end if

                if launchDarklyParamCtx.responseStatus = m.responseStatusMap.bodyPending then
                    return m.tryParseBody(launchDarklyParamCtx)
                end if

                return invalid
            end function,
        },

        responseStatus: 0,

        responseStatusText: function() as String
            launchDarklyLocalS = m.responseStatus

            if launchDarklyLocalS = 0 then
                return "header pending"
            else if launchDarklyLocalS = 1 then
                return "body pending"
            else if launchDarklyLocalS = 2 then
                return "response done"
            else if launchDarklyLocalS = -1 then
                return "no header found within max header length"
            else if launchDarklyLocalS = -2 then
                return "status not a valid number"
            else if launchDarklyLocalS = -3 then
                return "content length and transfer encoding conflict"
            else if launchDarklyLocalS = -4 then
                return "content length invalid number"
            else if launchDarklyLocalS = -5 then
                return "chunk length invalid hex"
            else if launchDarklyLocalS = -6 then
                return "status code not 3 digits"
            else if launchDarklyLocalS = -7 then
                return "unknown transfer encoding"
            else if launchDarklyLocalS = -8 then
                return "bad version format"
            end if

            return "unknown status"
        end function

        responseCode: invalid,
        responseMessage: invalid,
        responseHeaders: invalid,
        responseMajorVersion: invalid,
        responseMinorVersion: invalid,

        addBytes: function(launchDarklyParamBytes as Object) as Void
            m.private.stream.addBytes(launchDarklyParamBytes)
        end function,

        addText: function(launchDarklyParamText as String) as Void
            launchDarklyLocalBytes = createObject("roByteArray")
            launchDarklyLocalBytes.fromAsciiString(launchDarklyParamText)
            m.addBytes(launchDarklyLocalBytes)
        end function,

        streamHTTP: function() as Object
            return m.private.tryParseHTTP(m)
        end function
    }
end function
