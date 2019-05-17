function makeTestClient() as Object
    messagePort = CreateObject("roMessagePort")
    config = LaunchDarklyConfig("mob-abc123")
    config.setOffline(true)
    user = LaunchDarklyUser("user-key")
    return LaunchDarklyClient(config, user, messagePort)
end function

function makeTestClientOnline() as Object
    messagePort = CreateObject("roMessagePort")
    config = LaunchDarklyConfig("mob-abc123")
    user = LaunchDarklyUser("user-key")
    return LaunchDarklyClient(config, user, messagePort)
end function

function TestCase__Client_Eval_Offline() as String
    client = makeTestClient()
    fallback = "fallback"
    return m.assertEqual(client.variation("flag", fallback), fallback)
end function

function TestCase__Client_Eval_NotTracked() as String
    client = makeTestClientOnline()

    expectedValue = "def"
    client.private.store = {
        flag1: {
            value: expectedValue,
            variation: 3,
            version: 4
        }
    }

    actualValue = client.variation("flag1", "abc")

    a = m.assertEqual(actualValue, expectedValue)
    if a <> "" then
        return a
    end if

    eventQueue = client.private.events

    return m.assertEqual(eventQueue.count(), 0)
end function

function TestCase__Client_Eval_Tracked() as String
    client = makeTestClientOnline()

    future = client.private.getMilliseconds()
    future += 1000 * 10

    expectedValue = "def"
    expectedVariation = 3
    expectedFallback = "abc"
    expectedVersion = 5
    client.private.store = {
        flag1: {
            value: expectedValue,
            track: future,
            variation: expectedVariation,
            flagVersion: expectedVersion
        }
    }

    actualValue = client.variation("flag1", expectedFallback)

    a = m.assertEqual(actualValue, expectedValue)
    if a <> "" then
        return a
    end if

    eventQueue = client.private.events

    a = m.assertEqual(eventQueue.count(), 1)
    if a <> "" then
        return a
    end if

    event = eventQueue.getEntry(0)

    a = m.assertEqual(event.kind, "feature")
    if a <> "" then
        return a
    end if

    a = m.assertEqual(event.user, {
        key: "user-key"
    })
    if a <> "" then
        return a
    end if

    a = m.assertEqual(event.variation, expectedVariation)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(event.default, expectedFallback)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(event.version, expectedVersion)
    if a <> "" then
        return a
    end if

    return m.assertTrue(event.creationDate > 0)
end function

function TestCase__Client_Summary_Default() as String
    client = makeTestClientOnline()

    flagKey = "flag1"
    expectedFallback = "myFallback"

    actualValue = client.variation(flagKey, expectedFallback)
    client.variation(flagKey, expectedFallback)

    a = m.assertEqual(actualValue, expectedFallback)
    if a <> "" then
        return a
    end if

    event = client.private.makeSummaryEvent()

    a = m.assertEqual(event.kind, "summary")
    if a <> "" then
        return a
    end if

    a = m.assertEqual(event.user, {
        key: "user-key"
    })
    if a <> "" then
        return a
    end if

    a = m.assertTrue(event.startDate > 0)
    if a <> "" then
        return a
    end if

    a = m.assertTrue(event.endDate > 0)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(event.features.count(), 1)
    if a <> "" then
        return a
    end if

    feature = event.features.lookup(flagKey)

    a = m.assertEqual(feature.default, expectedFallback)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(feature.counters.count(), 1)
    if a <> "" then
        return a
    end if

    counter = feature.counters.getEntry(0)

    a = m.assertEqual(counter.value, expectedFallback)
    if a <> "" then
        return a
    end if

    return m.assertEqual(counter.count, 2)
end function

function TestCase__Client_Track() as String
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

    a = m.assertEqual(event.kind, "custom")
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

    return m.assertTrue(event.creationDate > 0)
end function

function TestCase__Client_Identify() as String
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

    return m.assertEqual(event.kind, "identify")
end function

function TestSuite__Client() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Client"

    this.addTest("TestCase__Client_Eval_Offline", TestCase__Client_Eval_Offline)
    this.addTest("TestCase__Client_Eval_NotTracked", TestCase__Client_Eval_NotTracked)
    this.addTest("TestCase__Client_Eval_Tracked", TestCase__Client_Eval_Tracked)
    this.addTest("TestCase__Client_Track", TestCase__Client_Track)
    this.addTest("TestCase__Client_Identify", TestCase__Client_Identify)
    this.addTest("TestCase__Client_Summary_Default", TestCase__Client_Summary_Default)

    return this
end function
