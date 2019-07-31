function TestCase__User_Constructor() as String
    user = LaunchDarklyUser("user-key")

    return m.assertEqual(user.private.key, "user-key")
end function

function TestCase__User_Encode_AllAttributes() as String
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

    actual = LaunchDarklyUserEncode(user, false)
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

function TestCase__User_Encode_RedactedAttributes() as String
    key = "alice-key"
    color = "blue"
    custom = {
        cookie: "abc123",
        color: color,
        magnitude: 3
    }
    avatar = "alice avatar"
    firstName = "alice"

    config = LaunchDarklyConfig("mob")
    config.addPrivateAttribute("magnitude")

    user = LaunchDarklyUser(key)
    user.setAvatar(avatar)
    user.setFirstName(firstName)
    user.setCustom(custom)
    user.addPrivateAttribute("avatar")
    user.addPrivateAttribute("cookie")
    user.addPrivateAttribute("DoesNotExist")

    privateAttrs = createObject("roArray", 0, true)
    privateAttrs.push("avatar")
    privateAttrs.push("magnitude")
    privateAttrs.push("cookie")

    actual = LaunchDarklyUserEncode(user, true, config)
    expected = {
        key: key,
        firstName: firstName,
        custom: {
            color: color
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
