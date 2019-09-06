function TestUtil__Crypto_Encrypt(launchDarklyParamCipherKey as Object, launchDarklyParamAuthKey as Object, launchDarklyParamBody as Object) as Object
    launchDarklyLocalIv = LaunchDarklyUtility().randomBytes(16)

    launchDarklyLocalCipherContext = createObject("roEVPCipher")
    a = launchDarklyLocalCipherContext.setup(true, "aes-256-cbc", launchDarklyParamCipherKey.toHexString(), launchDarklyLocalIv.toHexString(), 1)
    if a <> 0 then
        print "failed to setup cipher context"
        STOP
    end if

    launchDarklyLocalCipherText = launchDarklyLocalCipherContext.process(launchDarklyParamBody)

    launchDarklyLocalSize = launchDarklyUtility().unsignedIntegerToLittleEndian(launchDarklyLocalCipherText.count())

    launchDarklyLocalAuthContext = createObject("roHMAC")
    a = launchDarklyLocalAuthContext.setup("sha256", launchDarklyParamAuthKey)
    if a <> 0 then
        print "failed to setup authentication context"
        STOP
    end if

    launchDarklyLocalAuthContext.update(launchDarklyLocalSize)
    launchDarklyLocalAuthContext.update(launchDarklyLocalIv)
    launchDarklyLocalAuthContext.update(launchDarklyLocalCipherText)

    launchDarklyLocalAuthCode = launchDarklyLocalAuthContext.final()

    launchDarklyLocalResult = createObject("roByteArray")
    launchDarklyLocalResult.append(launchDarklyLocalSize)
    launchDarklyLocalResult.append(launchDarklyLocalIv)
    launchDarklyLocalResult.append(launchDarklyLocalAuthCode)
    launchDarklyLocalResult.append(launchDarklyLocalCipherText)

    return launchDarklyLocalResult
end function

function TestCase__Crypto_Decode_Basic() as String
    body = createObject("roByteArray")
    body.fromAsciiString(formatJSON({
        user: {
            key: "myKey1"
        }
    }))

    authKey = LaunchDarklyUtility().randomBytes(32)
    cipherKey = LaunchDarklyUtility().randomBytes(32)

    packet = TestUtil__Crypto_Encrypt(cipherKey, authKey, body)

    decoder = LaunchDarklyCryptoReader(cipherKey, authKey)
    decoder.addBytes(packet)

    clearText = decoder.consumeEvent()

    a = m.assertEqual(clearText.toAsciiString(), body.toAsciiString())
    if a <> "" then
        return a
    end if

    return m.assertEqual(decoder.getErrorCode(), 0)
end function

function TestCase__Crypto_Decode_BadBody() as String
    body = createObject("roByteArray")
    body.fromAsciiString(formatJSON({
        user: {
            key: "myKey2"
        }
    }))

    authKey = LaunchDarklyUtility().randomBytes(32)
    cipherKey = LaunchDarklyUtility().randomBytes(32)

    packet = TestUtil__Crypto_Encrypt(cipherKey, authKey, body)

    packet[32] = 0

    decoder = LaunchDarklyCryptoReader(cipherKey, authKey)
    decoder.addBytes(packet)

    a = m.assertEqual(decoder.consumeEvent(), invalid)
    if a <> "" then
        return a
    end if

    return m.assertEqual(decoder.getErrorCode(), 2)
end function

function TestCase__Crypto_Decode_Chunked() as String
    body = createObject("roByteArray")
    body.fromAsciiString(formatJSON({
        user: {
            key: "myKey3"
        }
    }))

    authKey = LaunchDarklyUtility().randomBytes(32)
    cipherKey = LaunchDarklyUtility().randomBytes(32)

    packet = TestUtil__Crypto_Encrypt(cipherKey, authKey, body)

    decoder = LaunchDarklyCryptoReader(cipherKey, authKey)

    for each byte in packet
        minimalByteArray = createObject("roByteArray")
        minimalByteArray.push(byte)

        decoder.addBytes(minimalByteArray)
    end for

    clearText = decoder.consumeEvent()

    a = m.assertEqual(clearText.toAsciiString(), body.toAsciiString())
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
