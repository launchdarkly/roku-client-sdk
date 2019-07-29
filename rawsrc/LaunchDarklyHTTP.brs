REM https://tools.ietf.org/html/rfc7230

function LaunchDarklyHTTPResponse() as Object
    util = LaunchDarklyUtility()

    return {
        private: {
            stream: LaunchDarklyStream(),
            util: util,

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

            colon: util.makeBytes(":"),
            space: util.makeBytes(" "),
            crlf: util.makeBytes(chr(13) + chr(10)),
            crlfcrlf: util.makeBytes(chr(13) + chr(10) + chr(13) + chr(10)),
            slash: util.makeBytes("/"),
            period: util.makeBytes("."),

            tryParseHeader: function(ctx as Object) as Integer
                header = m.stream.takeUntilSequence(m.crlfcrlf, true)
                if header = invalid then
                    if m.stream.count() > m.maxHeaderSize then
                        return m.responseStatusMap.noHeaderFoundWithinMaxHeaderLength
                    else
                        return 0
                    end if
                end if

                headerStream = LaunchDarklyStream(header)

                statusLine = headerStream.takeUntilSequence(m.crlf, true)
                if statusLine = invalid then
                    return m.responseStatusMap.badVersionFormat
                end if

                statusLineStream = LaunchDarklyStream(statusLine)

                responseVersion = statusLineStream.takeUntilSequence(m.space, true)
                if responseVersion = invalid then
                    return m.responseStatusMap.badVersionFormat
                end if
                responseVersionStream = LaunchDarklyStream(responseVersion)

                responseVersionPrefix = responseVersionStream.takeUntilSequence(m.slash)
                if responseVersionPrefix = invalid OR responseVersionPrefix.toAsciiString() <> "HTTP" then
                    return m.responseStatusMap.badVersionFormat
                end if

                majorVersion = responseVersionStream.takeUntilSequence(m.period)
                if majorVersion = invalid OR m.util.isNatural(majorVersion) = false then
                    return m.responseStatusMap.badVersionFormat
                end if
                majorVersion = majorVersion.toAsciiString().toInt()

                minorVersion = responseVersionStream.takeUntilSequence(m.space)
                if minorversion = invalid OR m.util.isNatural(minorVersion) = false then
                    return m.responseStatusMap.badVersionFormat
                end if
                minorVersion = minorVersion.toAsciiString().toInt()

                responseCode = statusLineStream.takeUntilSequence(m.space)
                if m.util.isNatural(responseCode) then
                    if responseCode.count() = 3 then
                        responseCode = responseCode.toAsciiString().toInt()
                    else
                        return m.responseStatusMap.statusCodeNot3Digits
                    end if
                else
                    return m.responseStatusMap.statusNotAValidNumber
                end if

                responseMessage = statusLineStream.takeUntilSequence(m.crlf).toAsciiString()

                responseHeaders = {}
                while true
                    headerField = headerStream.takeUntilSequence(m.crlf, true)

                    if headerField = invalid or headerField.count() <= 2 then
                        exit while
                    end if
                    headerFieldStream = LaunchDarklyStream(headerField)

                    fieldName = headerFieldStream.takeUntilSequence(m.colon)
                    fieldValue = headerFieldStream.takeUntilSequence(m.crlf)

                    while fieldValue.count() > 0 AND (fieldValue[0] = 32 OR fieldValue[0] = 0)
                        fieldValue.shift()
                    end while

                    responseHeaders[lCase(fieldName.toAsciiString())] = fieldValue.toAsciiString()
                end while

                contentLength = responseHeaders["content-length"]
                transferEncoding = responseHeaders["transfer-encoding"]

                if contentLength <> invalid AND transferEncoding <> invalid then
                    return m.responseStatusMap.contentLengthAndTransferEncodingConflict
                end if

                if contentLength <> invalid then
                    if m.util.isNatural(m.util.makeBytes(contentLength)) then
                        m.bodyStreamType = m.bodyStreamTypeMap.fixed
                        m.remainingContentLength = contentLength.toInt()
                    else
                        return m.responseStatusMap.contentLengthInvalidNumber
                    end if
                else
                    if transferEncoding <> invalid then
                        if transferEncoding = "chunked" then
                            m.bodyStreamType = m.bodyStreamTypeMap.chunked
                        else
                            return m.responseStatusMap.unknownTransferEncoding
                        end if
                    else
                        m.bodyStreamType = m.bodyStreamTypeMap.unknown
                    end if
                end if

                ctx.responseCode = responseCode
                ctx.responseMessage = responseMessage
                ctx.responseHeaders = responseHeaders
                ctx.responseMajorVersion = majorVersion
                ctx.responseMinorVersion = minorVersion

                return m.responseStatusMap.bodyPending
            end function,

            REM 1 = fixed size
            REM 2 = chunked
            REM 3 = unknown size
            bodyStreamType: invalid,
            REM when bodyStreamType = 1
            remainingContentLength: invalid,
            currentChunkSize: invalid,

            tryParseBody: function(ctx as Object) as Object
                responseBody = invalid

                if ctx.responseCode = 204 then
                    ctx.responseStatus = m.responseStatusMap.responseDone
                    return invalid
                else if m.bodyStreamType = m.bodyStreamTypeMap.unknown then
                    available = m.stream.count()

                    if available > 0 then
                        return m.stream.takeCount(available)
                    else
                        return invalid
                    end if
                else if m.bodyStreamType = m.bodyStreamTypeMap.fixed then
                    available = m.stream.count()

                    if available > m.remainingContentLength then
                        available = m.remainingContentLength
                    end if

                    responseBody = m.stream.takeCount(available)
                    m.remainingContentLength -= available

                    if m.remainingContentLength = 0 then
                        ctx.responseStatus = m.responseStatusMap.responseDone
                    end if
                else if m.bodyStreamType = m.bodyStreamTypeMap.chunked then
                    responseBody = createObject("roByteArray")

                    while true
                        if m.currentChunkSize = invalid then
                            chunkSize = m.stream.takeUntilSequence(m.crlf)

                            if chunkSize = invalid then
                                exit while
                            end if

                            chunkSize = m.util.hexToDecimal(chunkSize.toAsciiString())

                            if chunkSize = invalid then
                                ctx.responseStatus = m.responseStatusMap.chunkLengthInvalidHex
                                return invalid
                            else if chunkSize = 0 then
                                ctx.responseStatus = m.responseStatusMap.responseDone

                                exit while
                            end if

                            m.currentChunkSize = chunkSize
                        end if

                        if m.stream.count() < m.currentChunkSize + 2 then
                            exit while
                        end if

                        chunk = m.stream.takeCount(m.currentChunkSize)

                        m.stream.takeCount(2)

                        responseBody.append(chunk)

                        m.currentChunkSize = invalid
                    end while
                end if

                if responseBody = invalid OR responseBody.count() = 0 then
                    return invalid
                else
                    return responseBody
                end if
            end function

            tryParseHTTP: function(ctx as Object) as Object
                if ctx.responseStatus = m.responseStatusMap.headerPending then
                    ctx.responseStatus = m.tryParseHeader(ctx)
                end if

                if ctx.responseStatus = m.responseStatusMap.bodyPending then
                    return m.tryParseBody(ctx)
                end if

                return invalid
            end function,
        },

        responseStatus: 0,

        responseStatusText: function() as String
            s = m.responseStatus

            if s = 0 then
                return "header pending"
            else if s = 1 then
                return "body pending"
            else if s = 2 then
                return "response done"
            else if s = -1 then
                return "no header found within max header length"
            else if s = -2 then
                return "status not a valid number"
            else if s = -3 then
                return "content length and transfer encoding conflict"
            else if s = -4 then
                return "content length invalid number"
            else if s = -5 then
                return "chunk length invalid hex"
            else if s = -6 then
                return "status code not 3 digits"
            else if s = -7 then
                return "unknown transfer encoding"
            else if s = -8 then
                return "bad version format"
            end if

            return "unknown status"
        end function

        responseCode: invalid,
        responseMessage: invalid,
        responseHeaders: invalid,
        responseMajorVersion: invalid,
        responseMinorVersion: invalid,

        addBytes: function(bytes as Object) as Void
            m.private.stream.addBytes(bytes)
        end function,

        addText: function(text as String) as Void
            bytes = createObject("roByteArray")
            bytes.fromAsciiString(text)
            m.addBytes(bytes)
        end function,

        streamHTTP: function() as Object
            return m.private.tryParseHTTP(m)
        end function
    }
end function
