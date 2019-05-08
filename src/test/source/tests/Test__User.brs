function TestCase__User_Constructor()
    user = LaunchDarklyUser("user-key")
    return m.assertEqual(user.private.userKey, "user-key")
end function

function TestSuite__User() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__User"

    this.addTest("TestCase__User_Constructor", TestCase__User_Constructor)

    return this
end function
