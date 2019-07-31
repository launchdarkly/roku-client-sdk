function TestCase__Crypto_Decode_Basic() as String
    packetText = "IAAAAK7OgoWxB+TsNusZdv88vbFIdErD2wPfCdhj1i11jNvwywoegyXGGVtfqPBqS3jdBaCnhHDo8qQmyqakGzInCLG+DaaSmKX0ZB1DQo7L2c0u"

    authKey = createObject("roByteArray")
    authKey.fromBase64String("5wXLLS2zV99Uq9TopH1iqFtnrkpJI7VimDSl1lvzmgQ=")

    cipherKey = createObject("roByteArray")
    cipherKey.fromBase64String("WEIeuguICfc3gnlv42JQEw4o8UShna9BjCXOk2vo2fM=")

    packet = createObject("roByteArray")
    packet.fromBase64String(packetText)

    decoder = LaunchDarklyCryptoReader(cipherKey, authKey)
    decoder.addBytes(packet)
    decoder.addBytes(packet)

    clearText = decoder.consumeEvent()

    a = m.assertEqual(parseJSON(clearText.toAsciiString()), {
        user: {
            key: "myKey"
        }
    })
    if a <> "" then
        return a
    end if

    return m.assertEqual(decoder.getErrorCode(), 0)
end function

function TestCase__Crypto_Decode_BadBody() as String
    packetText = "IAAAALGRx5qkoGNT81Q51Py3iImf7LQRe0fRcQxcGWtQ5MLt+3Fie5yRAvvjqrcfTdmHDGiofndY8bGU43gkTzO/J4qeWpnSoRaYbsse58j1WzgV"

    authKey = createObject("roByteArray")
    authKey.fromBase64String("5wXLLS2zV99Uq9TopH1iqFtnrkpJI7VimDSl1lvzmgQ=")

    cipherKey = createObject("roByteArray")
    cipherKey.fromBase64String("WEIeuguICfc3gnlv42JQEw4o8UShna9BjCXOk2vo2fM=")

    packet = createObject("roByteArray")
    packet.fromBase64String(packetText)

    decoder = LaunchDarklyCryptoReader(cipherKey, authKey)
    decoder.addBytes(packet)

    a = m.assertEqual(decoder.consumeEvent(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(decoder.getErrorCode(), 2)
end function

function TestCase__Crypto_Decode_Chunked() as String
    packetText = "IAAAAK7OgoWxB+TsNusZdv88vbFIdErD2wPfCdhj1i11jNvwywoegyXGGVtfqPBqS3jdBaCnhHDo8qQmyqakGzInCLG+DaaSmKX0ZB1DQo7L2c0u"

    authKey = createObject("roByteArray")
    authKey.fromBase64String("5wXLLS2zV99Uq9TopH1iqFtnrkpJI7VimDSl1lvzmgQ=")

    cipherKey = createObject("roByteArray")
    cipherKey.fromBase64String("WEIeuguICfc3gnlv42JQEw4o8UShna9BjCXOk2vo2fM=")

    packet = createObject("roByteArray")
    packet.fromBase64String(packetText)

    decoder = LaunchDarklyCryptoReader(cipherKey, authKey)

    for each byte in packet
        minimalByteArray = createObject("roByteArray")
        minimalByteArray.push(byte)

        decoder.addBytes(minimalByteArray)
    end for

    clearText = decoder.consumeEvent()

    a = m.assertEqual(parseJSON(clearText.toAsciiString()), {
        user: {
            key: "myKey"
        }
    })
    if a <> "" then
        return a
    end if

    return m.assertEqual(decoder.getErrorCode(), 0)
end function

function TestSuite__Crypto() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Crypto"

    this.addTest("TestCase__Crypto_Decode_Basic", TestCase__Crypto_Decode_Basic)
    this.addTest("TestCase__Crypto_Decode_BadBody", TestCase__Crypto_Decode_BadBody)
    this.addTest("TestCase__Crypto_Decode_Chunked", TestCase__Crypto_Decode_Chunked)

    return this
end function
