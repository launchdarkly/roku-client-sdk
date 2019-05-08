function TestCase__User_Constructor()
    user = LaunchDarklyUser("user-key")
    return m.assertEqual(user.private.key, "user-key")
end function

function TestCase__User_Encode_Trivial()
    user = LaunchDarklyUser("my-key")
    encoded = user.private.encode()
    regex = CreateObject("roRegex", "\|", "")
    expected = regex.replaceAll("{|key|:|my-key|}", chr(34))
    return m.assertEqual(encoded, expected)
end function

function TestSuite__User() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__User"

    this.addTest("TestCase__User_Constructor", TestCase__User_Constructor)
    this.addTest("TestCase__User_Encode_Trivial", TestCase__User_Encode_Trivial)

    return this
end function
