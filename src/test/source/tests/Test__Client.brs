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

    a = m.assertTrue(event.creationDate > 0)
    if a <> "" then
        return a
    end if

    event.delete("creationDate")

    return m.assertEqual(event, {
        kind: "feature",
        user: {
            key: "user-key"
        },
        value: expectedValue,
        variation: expectedVariation,
        default: expectedFallback,
        version: expectedVersion
    })
end function

function TestCase__Client_Summary_Known() as String
    client = makeTestClientOnline()

    flagKey = "flag1"
    fallback = "myFallback"
    expectedValue = "expected"

    client.private.store = {
        flag1: {
            value: expectedValue,
            variation: 3,
            version: 4
        }
    }

    actualValue = client.variation(flagKey, fallback)
    client.variation(flagKey, fallback)

    a = m.assertEqual(actualValue, expectedValue)
    if a <> "" then
        return a
    end if

    event = client.private.makeSummaryEvent()

    a = m.assertTrue(event.creationDate > 0)
    if a <> "" then
        return a
    end if
    event.delete("creationDate")

    a = m.assertTrue(event.endDate > 0)
    if a <> "" then
        return a
    end if
    event.delete("endDate")

    a = m.assertTrue(event.startDate > 0)
    if a <> "" then
        return a
    end if
    event.delete("startDate")

    counters = createObject("roArray", 0, true)
    counters.push({
        version: 4,
        variation: 3,
        count: 2,
        value: expectedValue
    })

    return m.assertEqual(FormatJSON(event), FormatJSON({
        kind: "summary",
        features: {
            flag1: {
                default: fallback,
                counters: counters
            }
        },
        user: {
            key: "user-key"
        }
    }))
end function


function TestCase__Client_Summary_Unknown() as String
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

    a = m.assertTrue(event.creationDate > 0)
    if a <> "" then
        return a
    end if
    event.delete("creationDate")

    a = m.assertTrue(event.endDate > 0)
    if a <> "" then
        return a
    end if
    event.delete("endDate")

    a = m.assertTrue(event.startDate > 0)
    if a <> "" then
        return a
    end if
    event.delete("startDate")

    counters = createObject("roArray", 0, true)
    counters.push({
        count: 2,
        value: expectedFallback,
        unknown: true
    })

    return m.assertEqual(FormatJSON(event), FormatJSON({
        kind: "summary",
        features: {
            flag1: {
                default: expectedFallback,
                counters: counters
            }
        },
        user: {
            key: "user-key"
        }
    }))
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

function testVariation(ctx as Object, functionName as String, expectedValue as Dynamic, fallback as Dynamic) as String
    client = makeTestClientOnline()

    flagKey = "flag1"

    client.private.store = {
        flag1: {
            value: expectedValue,
            variation: 3,
            version: 4
        }
    }

    actualValue = client[functionName](flagKey, fallback)

    return ctx.assertEqual(actualValue, expectedValue)
end function

function TestCase__Client_Variation_Int() as String
    return testVariation(m, "variationInt", 13, 5)
end function

function TestCase__Client_Variation_Bool() as String
    return testVariation(m, "variationBool", true, false)
end function

function TestCase__Client_Variation_String() as String
    return testVariation(m, "variationString", "abc", "def")
end function

function TestCase__Client_Variation_AA() as String
    return testVariation(m, "variationAA", { b: 6 }, { a: 4 })
end function

function TestSuite__Client() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Client"

    this.addTest("TestCase__Client_Eval_Offline", TestCase__Client_Eval_Offline)
    this.addTest("TestCase__Client_Eval_NotTracked", TestCase__Client_Eval_NotTracked)
    this.addTest("TestCase__Client_Eval_Tracked", TestCase__Client_Eval_Tracked)
    this.addTest("TestCase__Client_Track", TestCase__Client_Track)
    this.addTest("TestCase__Client_Identify", TestCase__Client_Identify)
    this.addTest("TestCase__Client_Summary_Unknown", TestCase__Client_Summary_Unknown)
    this.addTest("TestCase__Client_Summary_Known", TestCase__Client_Summary_Known)
    this.addTest("TestCase__Client_Variation_Int", TestCase__Client_Variation_Int)
    this.addTest("TestCase__Client_Variation_Bool", TestCase__Client_Variation_Bool)
    this.addTest("TestCase__Client_Variation_String", TestCase__Client_Variation_String)
    this.addTest("TestCase__Client_Variation_AA", TestCase__Client_Variation_AA)

    return this
end function
