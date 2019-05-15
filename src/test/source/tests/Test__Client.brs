function makeTestClient() as Object
    messagePort = CreateObject("roMessagePort")
    config = LaunchDarklyConfig("mob-abc123")
    config.setOffline(true)
    user = LaunchDarklyUser("user-key")
    return LaunchDarklyClient(config, user, messagePort)
end function

function TestCase__Client_Eval_Offline()
    client = makeTestClient()
    fallback = "fallback"
    return m.assertEqual(client.variation("flag", fallback), fallback)
end function

function TestCase__Client_Track()
    client = makeTestClient()
    fallback = "fallback"

    eventName = "my-event"
    eventData = {
        a: 2,
        b: 3
    }

    client.track(eventName, eventData)

    eventQueue = client.private.events

    a = m.assertEqual(eventQueue.count(), 1)
    if a <> "" then
        return a
    end if

    event = eventQueue.getEntry(0)

    a = m.assertEqual(event.kind, "track")
    if a <> "" then
        return a
    end if

    a = m.assertEqual(event.user, {
        key: "user-key"
    })
    if a <> "" then
        return a
    end if

    a = m.assertEqual(event.key, eventName)
    if a <> "" then
        return a
    end if

    a = m.assertTrue(event.creationDate > 0)
    if a <> "" then
        return a
    end if

    return ""
end function

function TestCase__Client_Identify()
    client = makeTestClient()

    newUserKey = "user-key2"
    newUser = LaunchDarklyUser(newUserKey)

    client.identify(newUser)

    a = m.assertEqual(client.private.user.private.key, newUserKey)
    if a <> "" then
        return a
    end if

    eventQueue = client.private.events

    a = m.assertEqual(eventQueue.count(), 1)
    if a <> "" then
        return a
    end if

    event = eventQueue.getEntry(0)

    a = m.assertEqual(event.kind, "identify")
    if a <> "" then
        return a
    end if

    return ""
end function

function TestSuite__Client() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Client"

    this.addTest("TestCase__Client_Eval_Offline", TestCase__Client_Eval_Offline)
    this.addTest("TestCase__Client_Track", TestCase__Client_Track)
    this.addTest("TestCase__Client_Identify", TestCase__Client_Identify)

    return this
end function
