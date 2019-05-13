function TestCase__User_Constructor()
    user = LaunchDarklyUser("user-key")

    return m.assertEqual(user.private.key, "user-key")
end function

function TestCase__User_Encode_AllAttributes()
    key = "alice-key"
    anonymous = false
    firstName = "Alice"
    lastName = "Smith"
    email = "alicesmith@example.com"
    name = "Alice Smith"
    avatar = "alice avatar"
    custom = {
        cookie: "abc123"
    }

    user = LaunchDarklyUser(key)
    user.setAnonymous(anonymous)
    user.setFirstName(firstName)
    user.setLastName(lastName)
    user.setEmail(email)
    user.setName(name)
    user.setAvatar(avatar)
    user.setCustom(custom)

    actual = user.private.encode(false)
    expected = {
        key: key,
        firstName: firstName,
        lastName: lastName,
        email: email,
        name: name,
        avatar: avatar,
        custom: custom
    }

    return m.assertEqual(actual, expected)
end function

function TestCase__User_Encode_RedactedAttributes()
    key = "alice-key"
    custom = {
        cookie: "abc123",
        color: "blue",
        magnitude: 3
    }

    config = LaunchDarklyConfig("mob")
    config.addPrivateAttribute("magnitude")

    user = LaunchDarklyUser(key)
    user.setCustom(custom)
    user.addPrivateAttribute("cookie")
    user.addPrivateAttribute("DoesNotExist")

    privateAttrs = createObject("roArray", 0, true)
    privateAttrs.push("magnitude")
    privateAttrs.push("cookie")

    actual = user.private.encode(true, config)
    expected = {
        key: key,
        custom: {
            color: "blue"
        },
        privateAttrs: privateAttrs
    }

    return m.assertEqual(actual, expected)
end function

function TestSuite__User() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__User"

    this.addTest("TestCase__User_Constructor", TestCase__User_Constructor)
    this.addTest("TestCase__User_Encode_AllAttributes", TestCase__User_Encode_AllAttributes)
    this.addTest("TestCase__User_Encode_RedactedAttributes", TestCase__User_Encode_RedactedAttributes)

    return this
end function
