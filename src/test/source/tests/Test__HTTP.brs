function TestCase__HTTP_NoBodyNoHeadersFull() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/1.0 204 No Content" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseStatus, 2)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseCode, 204)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMessage, "No Content")
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMajorVersion, 1)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMinorVersion, 0)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseHeaders, {})
    if a <> "" then
        return a
    end if

    return ""
end function

function TestCase__HTTP_NoBodyWithHeadersFull() as Object
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/1.1 204 No Content" + chr(13) + chr(10))
    http.addText("Connection: Keep-Alive" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseStatus, 2)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseCode, 204)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMessage, "No Content")
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMajorVersion, 1)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMinorVersion, 1)
    if a <> "" then
        return a
    end if

    responseHeaders = {}
    responseHeaders["connection"] = "Keep-Alive"

    a = m.assertEqual(http.responseHeaders, responseHeaders)
    if a <> "" then
        return a
    end if

    return ""
end function

function TestCase__HTTP_StaticBodyWithHeadersFull() as String
    http = LaunchDarklyHTTPResponse()

    body = createObject("roByteArray")
    body.fromAsciiString("Hello World!")

    http.addText("HTTP/1.1 200 OK" + chr(13) + chr(10))
    http.addText("Connection: Keep-Alive" + chr(13) + chr(10))
    http.addText("Content-Length: " + body.count().toStr() + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))
    http.addBytes(body)

    a = m.assertEqual(http.streamHTTP().toHexString(), body.toHexString())
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseStatus, 2)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseCode, 200)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMessage, "OK")
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMajorVersion, 1)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMinorVersion, 1)
    if a <> "" then
        return a
    end if

    responseHeaders = {}
    responseHeaders["connection"] = "Keep-Alive"
    responseHeaders["content-length"] = body.count().toStr()

    a = m.assertEqual(http.responseHeaders, responseHeaders)
    if a <> "" then
        return a
    end if

    return ""
end function

function TestCase__HTTP_ChunkedBodyWithHeadersFull() as String
    http = LaunchDarklyHTTPResponse()

    bodyText = ""
    bodyText += "D"  + chr(13) + chr(10)
    bodyText += "LaunchDarkly " + chr(13) + chr(10)
    bodyText += "11"  + chr(13) + chr(10)
    bodyText += "HTTP Stream Test " + chr(13) + chr(10)
    bodyText += "4"  + chr(13) + chr(10)
    bodyText += "Body" + chr(13) + chr(10)
    bodyText += "0"  + chr(13) + chr(10)
    bodyText += chr(13) + chr(10)

    body = createObject("roByteArray")
    body.fromAsciiString(bodyText)

    http.addText("HTTP/1.1 200 OK" + chr(13) + chr(10))
    http.addText("Transfer-Encoding: chunked" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))
    http.addBytes(body)

    expectedBody = createObject("roByteArray")
    expectedBody.fromAsciiString("LaunchDarkly HTTP Stream Test Body")

    a = m.assertEqual(http.streamHTTP().toHexString(), expectedBody.toHexString())
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseStatus, 2)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseCode, 200)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMessage, "OK")
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMajorVersion, 1)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMinorVersion, 1)
    if a <> "" then
        return a
    end if

    responseHeaders = {}
    responseHeaders["transfer-encoding"] = "chunked"

    a = m.assertEqual(http.responseHeaders, responseHeaders)
    if a <> "" then
        return a
    end if

    return ""
end function

function TestCase__HTTP_NoBodyWithHeadersStreamed() as Object
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/1.1")

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    http.addText(" 204 No Content" + chr(13))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    http.addText(chr(10) + "Connection")

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseStatus, 0)
    if a <> "" then
        return a
    end if

    http.addText(": Keep-Alive")
    http.addText(chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseStatus, 2)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseCode, 204)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMessage, "No Content")
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMajorVersion, 1)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMinorVersion, 1)
    if a <> "" then
        return a
    end if

    responseHeaders = {}
    responseHeaders["connection"] = "Keep-Alive"

    a = m.assertEqual(formatJSON(http.responseHeaders), formatJSON(responseHeaders))
    if a <> "" then
        return a
    end if

    return ""
end function

function TestCase__HTTP_StaticBodyWithHeadersStreamed() as String
    http = LaunchDarklyHTTPResponse()

    body1 = createObject("roByteArray")
    body1.fromAsciiString("Hello")

    body2 = createObject("roByteArray")
    body2.fromAsciiString(" World!")

    totalBodySize = body1.count() + body2.count()

    http.addText("HTTP/1.1 200 OK" + chr(13) + chr(10))
    http.addText("Connection: Keep-Alive" + chr(13) + chr(10))
    http.addText("Content-Length: " + totalBodySize.toStr() + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    http.addBytes(body1)
    a = m.assertEqual(http.streamHTTP().toHexString(), body1.toHexString())
    if a <> "" then
        return a
    end if

    http.addBytes(body2)
    a = m.assertEqual(http.streamHTTP().toHexString(), body2.toHexString())
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseStatus, 2)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseCode, 200)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMessage, "OK")
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMajorVersion, 1)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMinorVersion, 1)
    if a <> "" then
        return a
    end if

    responseHeaders = {}
    responseHeaders["connection"] = "Keep-Alive"
    responseHeaders["content-length"] = totalBodySize.toStr()

    a = m.assertEqual(formatJSON(http.responseHeaders), formatJSON(responseHeaders))
    if a <> "" then
        return a
    end if

    return ""
end function

function TestCase__HTTP_ChunkedBodyWithHeadersStreamed() as String
    http = LaunchDarklyHTTPResponse()

    body = createObject("roByteArray")

    http.addText("HTTP/1.1 200 OK" + chr(13) + chr(10))
    http.addText("Transfer-Encoding: chunked" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    expectedBody = createObject("roByteArray")

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    body.fromAsciiString("C" + chr(13) + chr(10) + "Launch")
    http.addBytes(body)

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    body.fromAsciiString("Darkly" + chr(13) + chr(10))
    http.addBytes(body)

    expectedBody.fromAsciiString("LaunchDarkly")

    a = m.assertEqual(http.streamHTTP().toHexString(), expectedBody.toHexString())
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseStatus, 1)
    if a <> "" then
        return a
    end if

    body.fromAsciiString("0" + chr(13) + chr(10))
    http.addBytes(body)

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseStatus, 2)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseCode, 200)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMessage, "OK")
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMajorVersion, 1)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseMinorVersion, 1)
    if a <> "" then
        return a
    end if

    responseHeaders = {}
    responseHeaders["transfer-encoding"] = "chunked"

    a = m.assertEqual(http.responseHeaders, responseHeaders)
    if a <> "" then
        return a
    end if

    return ""
end function

function TestCase__HTTP_InvalidResponseCode() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/1.1 1abc No Content" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(http.responseStatus, -2)
end function

function TestCase__HTTP_ContentLengthAndTransferEncoding() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/1.1 200 OK" + chr(13) + chr(10))
    http.addText("Content-Length: 32" + chr(13) + chr(10))
    http.addText("Transfer-Encoding: chunked" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(http.responseStatus, -3)
end function

function TestCase__HTTP_ContentLengthInvalidNumber() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/1.1 200 OK" + chr(13) + chr(10))
    http.addText("Content-Length: abc" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(http.responseStatus, -4)
end function

function TestCase__HTTP_ChunkedBadLength() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/1.1 200 OK" + chr(13) + chr(10))
    http.addText("Transfer-Encoding: chunked" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))
    http.addText("z3"  + chr(13) + chr(10))
    http.addText("HTTP Stream Test " + chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(http.responseStatus, -5)
end function

function TestCase__HTTP_ResponseCodeIncorrectLength() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/1.1 1337 OK" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(http.responseStatus, -6)
end function

function TestCase__HTTP_UnknownTransferEncoding() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/1.1 200 OK" + chr(13) + chr(10))
    http.addText("Transfer-Encoding: other" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(http.responseStatus, -7)
end function

function TestCase__HTTP_BadStatusPrefix() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("ABC/1.1 200 OK" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(http.responseStatus, -8)
end function

function TestCase__HTTP_BadMajorVersion() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/A.1 200 OK" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(http.responseStatus, -8)
end function

function TestCase__HTTP_BadMinorVersion() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/1.B 200 OK" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(http.responseStatus, -8)
end function

function TestCase__HTTP_MalformedStatusLine() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP|12|15 200 OK" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(http.responseStatus, -8)
end function

function TestCase__HTTP_EmptyHeaderValue() as String
    http = LaunchDarklyHTTPResponse()

    http.addText("HTTP/1.1 204 No Content" + chr(13) + chr(10))
    http.addText("my-header:" + chr(13) + chr(10))
    http.addText(chr(13) + chr(10))

    a = m.assertEqual(http.streamHTTP(), invalid)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(http.responseStatus, 2)
    if a <> "" then
        return a
    end if

    responseHeaders = {}
    responseHeaders["my-header"] = ""

    return m.assertEqual(http.responseHeaders, responseHeaders)
end function

function TestSuite__HTTP() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__HTTP"

    this.addTest("TestCase__HTTP_NoBodyNoHeadersFull", TestCase__HTTP_NoBodyNoHeadersFull)
    this.addTest("TestCase__HTTP_NoBodyWithHeadersFull", TestCase__HTTP_NoBodyWithHeadersFull)
    this.addTest("TestCase__HTTP_StaticBodyWithHeadersFull", TestCase__HTTP_StaticBodyWithHeadersFull)
    this.addTest("TestCase__HTTP_ChunkedBodyWithHeadersFull", TestCase__HTTP_ChunkedBodyWithHeadersFull)
    this.addTest("TestCase__HTTP_NoBodyWithHeadersStreamed", TestCase__HTTP_NoBodyWithHeadersStreamed)
    this.addTest("TestCase__HTTP_StaticBodyWithHeadersStreamed", TestCase__HTTP_StaticBodyWithHeadersStreamed)
    this.addTest("TestCase__HTTP_ChunkedBodyWithHeadersStreamed", TestCase__HTTP_ChunkedBodyWithHeadersStreamed)
    this.addTest("TestCase__HTTP_InvalidResponseCode", TestCase__HTTP_InvalidResponseCode)
    this.addTest("TestCase__HTTP_ContentLengthAndTransferEncoding", TestCase__HTTP_ContentLengthAndTransferEncoding)
    this.addTest("TestCase__HTTP_ContentLengthInvalidNumber", TestCase__HTTP_ContentLengthInvalidNumber)
    this.addTest("TestCase__HTTP_ChunkedBadLength", TestCase__HTTP_ChunkedBadLength)
    this.addTest("TestCase__HTTP_ResponseCodeIncorrectLength", TestCase__HTTP_ResponseCodeIncorrectLength)
    this.addTest("TestCase__HTTP_UnknownTransferEncoding", TestCase__HTTP_UnknownTransferEncoding)
    this.addTest("TestCase__HTTP_BadStatusPrefix", TestCase__HTTP_BadStatusPrefix)
    this.addTest("TestCase__HTTP_BadMajorVersion", TestCase__HTTP_BadMajorVersion)
    this.addTest("TestCase__HTTP_BadMinorVersion", TestCase__HTTP_BadMinorVersion)
    this.addTest("TestCase__HTTP_MalformedStatusLine", TestCase__HTTP_MalformedStatusLine)
    this.addTest("TestCase__HTTP_EmptyHeaderValue", TestCase__HTTP_EmptyHeaderValue)

    return this
end function
