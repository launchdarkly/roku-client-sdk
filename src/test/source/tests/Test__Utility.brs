function TestCase__Utility_MemCpy_Start() as String
    source = createObject("roByteArray")
    source.fromHexString("6DC91200")

    expected = createObject("roByteArray")
    expected.fromHexString("6DC9")

    destination = createObject("roByteArray")
    destination.setResize(2, false)

    LaunchDarklyUtility().memcpy(source, 0, destination, 0, 2)

    return m.assertEqual(expected.toHexString(), destination.toHexString())
end function

function TestCase__Utility_MemCpy_Mid() as String
    source = createObject("roByteArray")
    source.fromHexString("6DC91200")

    expected = createObject("roByteArray")
    expected.fromHexString("01C912")

    destination = createObject("roByteArray")
    destination.fromHexString("01")
    destination.setResize(3, false)

    LaunchDarklyUtility().memcpy(source, 1, destination, 1, 2)

    return m.assertEqual(expected.toHexString(), destination.toHexString())
end function

function TestCase__Utility_HexToDecimal() as String
    u = LaunchDarklyUtility()

    a = m.assertEqual(u.hexToDecimal("7B"), 123)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(u.hexToDecimal("5"), 5)
    if a <> "" then
        return a
    end if

    return m.assertEqual(u.hexToDecimal("1d4"), 468)
end function

function TestCase__Utility_Endian() as String
    encoded = createObject("roByteArray")
    encoded.fromHexString("6DC91200")

    decoded = LaunchDarklyUtility().littleEndianUnsignedToInteger(encoded)

    return m.assertEqual(decoded, 1231213)
end function

function TestCase__Utility_ByteArrayEq() as String
    u = LaunchDarklyUtility()

    a = m.assertTrue(u.byteArrayEq(u.makeBytes("abcd"), u.makeBytes("abcd")))
    if a <> "" then
        return a
    end if

    return m.assertFalse(u.byteArrayEq(u.makeBytes("abcd"), u.makeBytes("1234")))
end function

function TestCase__Utility_IsValidHex() as String
    u = LaunchDarklyUtility()

    a = m.assertTrue(u.isValidHex("7B"))
    if a <> "" then
        return a
    end if

    a = m.assertTrue(u.isValidHex("5"))
    if a <> "" then
        return a
    end if

    a = m.assertTrue(u.isValidHex("1d4"))
    if a <> "" then
        return a
    end if

    a = m.assertFalse(u.isValidHex("hello world"))
    if a <> "" then
        return a
    end if

    return m.assertFalse(u.isValidHex(""))
end function

function TestCase__Utility_GetMilliseconds() as String
    return m.assertTrue(LaunchDarklyUtility().getMilliseconds() > 0)
end function

function TestCase__Utility_Backoff() as String
    backoff = LaunchDarklyBackoff()

    backoff.started()

    a = m.assertFalse(backoff.shouldWait())
    if a <> "" then
        return a
    end if

    backoff.finished()

    a = m.assertTrue(backoff.shouldWait())
    if a <> "" then
        return a
    end if

    backoff.reset()

    return m.assertFalse(backoff.shouldWait())
end function

function TestCase__Utility_StripHTTPProtocol() as String
    u = LaunchDarklyUtility()

    a = m.assertEqual(u.stripHTTPProtocol("https://test.com"), "test.com")
    if a <> "" then
        return a
    end if

    a = m.assertEqual(u.stripHTTPProtocol("http://test.com"), "test.com")
    if a <> "" then
        return a
    end if

    return m.assertEqual(u.stripHTTPProtocol("test.com"), "")
end function

function TestCase__Utility_ExtractUriParts() as String
    u = LaunchDarklyUtility()

    testCases = {
      "example.com": { "scheme": "http", "host": "example.com", "port": invalid, "path": "" },
      "http://example.com": { "scheme": "http", "host": "example.com", "port": invalid, "path": "" },
      "https://example.com": { "scheme": "https", "host": "example.com", "port": invalid, "path": "" },
      "https://example.com:8000": { "scheme": "https", "host": "example.com", "port": 8000, "path": "" },
      "https://example.com/": { "scheme": "https", "host": "example.com", "port": invalid, "path": "" },
      "https://example.com//": { "scheme": "https", "host": "example.com", "port": invalid, "path": "" },
      "https://example.com/multi/part/path/": { "scheme": "https", "host": "example.com", "port": invalid, "path": "/multi/part/path" },
      "https://example.com?query=parameter": { "scheme": "https", "host": "example.com", "port": invalid, "path": "" },
      "https://example.com/path/with?query=parameter": { "scheme": "https", "host": "example.com", "port": invalid, "path": "/path/with" },
      "https://example.com/path/with/trailing/slash/?query=parameter": { "scheme": "https", "host": "example.com", "port": invalid, "path": "/path/with/trailing/slash" },
      "https://example.com?/invalid-setup": invalid,
    }

    for each uri in testCases
      parts = u.extractUriParts(uri)
      result = m.assertEqual(parts, testCases[uri])
      if result <> "" then
        return result
      end if
    end for

    return ""
end function

function TestCase__Utility_RandomBytes() as String
    bytes1 = LaunchDarklyUtility().randomBytes(16)

    a = m.assertEqual(bytes1.count(), 16)
    if a <> "" then
        return a
    end if

    bytes2 = LaunchDarklyUtility().randomBytes(16)

    return m.assertNotEqual(bytes1.toHexString(), bytes2.toHexString())
end function

function TestCase__Utility_UnsignedIntegerToLittleEndian() as String
    bytes = LaunchDarklyUtility().unsignedIntegerToLittleEndian(257)
    a = m.assertEqual(bytes.toHexString(), "01010000")
    if a <> "" then
        return a
    end if

    bytes = LaunchDarklyUtility().unsignedIntegerToLittleEndian(12971)
    return m.assertEqual(bytes.toHexString(), "AB320000")
end function

function TestSuite__Utility() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Utility"

    this.addTest("TestCase__Utility_MemCpy_Start", TestCase__Utility_MemCpy_Start)
    this.addTest("TestCase__Utility_MemCpy_Mid", TestCase__Utility_MemCpy_Mid)
    this.addTest("TestCase__Utility_HexToDecimal", TestCase__Utility_HexToDecimal)
    this.addTest("TestCase__Utility_Endian", TestCase__Utility_Endian)
    this.addTest("TestCase__Utility_ByteArrayEq", TestCase__Utility_ByteArrayEq)
    this.addTest("TestCase__Utility_IsValidHex", TestCase__Utility_IsValidHex)
    this.addTest("TestCase__Utility_GetMilliseconds", TestCase__Utility_GetMilliseconds)
    this.addTest("TestCase__Utility_Backoff", TestCase__Utility_Backoff)
    this.addTest("TestCase__Utility_StripHTTPProtocol", TestCase__Utility_StripHTTPProtocol)
    this.addTest("TestCase__Utility_ExtractUriParts", TestCase__Utility_ExtractUriParts)
    this.addTest("TestCase__Utility_RandomBytes", TestCase__Utility_RandomBytes)
    this.addTest("TestCase__Utility_UnsignedIntegerToLittleEndian", TestCase__Utility_UnsignedIntegerToLittleEndian)

    return this
end function
