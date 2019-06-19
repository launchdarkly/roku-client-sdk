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

function TestSuite__Utility() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Utility"

    this.addTest("TestCase__Utility_MemCpy_Start", TestCase__Utility_MemCpy_Start)
    this.addTest("TestCase__Utility_MemCpy_Mid", TestCase__Utility_MemCpy_Mid)
    this.addTest("TestCase__Utility_Endian", TestCase__Utility_Endian)
    this.addTest("TestCase__Utility_ByteArrayEq", TestCase__Utility_ByteArrayEq)

    return this
end function
