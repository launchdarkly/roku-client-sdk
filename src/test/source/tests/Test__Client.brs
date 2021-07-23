function makeTestClientUninitialized() as Object
    messagePort = CreateObject("roMessagePort")
    config = LaunchDarklyConfig("mob-abc123")
    config.setOffline(true)
    user = LaunchDarklyUser("user-key")
    return LaunchDarklyClient(config, user, messagePort)
end function

function makeTestClientInitialized() as Object
    messagePort = CreateObject("roMessagePort")
    config = LaunchDarklyConfig("mob-abc123")
    user = LaunchDarklyUser("user-key")
    config.setOffline(true)
    client = LaunchDarklyClient(config, user, messagePort)
    client.status.private.setStatus(client.status.map.initialized)
    return client
end function

function TestCase__Client_Eval_Offline() as String
    client = makeTestClientUninitialized()
    fallback = "fallback"
    return m.assertEqual(client.variation("flag", fallback), fallback)
end function

function TestCase__Client_Eval_NotTracked() as String
    client = makeTestClientInitialized()

    expectedValue = "def"
    client.private.store.putAll({
        flag1: {
            value: expectedValue,
            variation: 3,
            version: 4
        }
    })

    actualValue = client.variation("flag1", "abc")

    a = m.assertEqual(actualValue, expectedValue)
    if a <> "" then
        return a
    end if

    eventQueue = client.private.eventProcessor.flush()

    return m.assertEqual(eventQueue.count(), 2)
end function

function TestCase__Client_Eval_Tracked() as String
    client = makeTestClientInitialized()

    expectedValue = "def"
    expectedVariation = 3
    expectedFallback = "abc"
    expectedVersion = 5
    client.private.store.putAll({
        flag1: {
            value: expectedValue,
            trackEvents: true,
            variation: expectedVariation,
            flagVersion: expectedVersion
        }
    })

    actualValue = client.variation("flag1", expectedFallback)

    a = m.assertEqual(actualValue, expectedValue)
    if a <> "" then
        return a
    end if

    eventQueue = client.private.eventProcessor.flush()

    a = m.assertEqual(eventQueue.count(), 3)
    if a <> "" then
        return a
    end if

    event = eventQueue.getEntry(1)

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
        key: "flag1",
        value: expectedValue,
        variation: expectedVariation,
        default: expectedFallback,
        version: expectedVersion
    })
end function

function TestCase__Client_Summary_Known() as String
    client = makeTestClientInitialized()

    flagKey = "flag1"
    fallback = "myFallback"
    expectedValue = "expected"

    client.private.store.putAll({
        flag1: {
            value: expectedValue,
            variation: 3,
            version: 4
        }
    })

    actualValue = client.variation(flagKey, fallback)
    client.variation(flagKey, fallback)

    a = m.assertEqual(actualValue, expectedValue)
    if a <> "" then
        return a
    end if

    events = client.private.eventProcessor.flush()

    a = m.assertEqual(events.count(), 2)
    if a <> "" then
        return a
    end if

    event = events[1]

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
        }
    }))
end function

function TestCase__Client_Summary_Unknown() as String
    client = makeTestClientInitialized()

    flagKey = "flag1"
    expectedFallback = "myFallback"

    actualValue = client.variation(flagKey, expectedFallback)
    client.variation(flagKey, expectedFallback)

    a = m.assertEqual(actualValue, expectedFallback)
    if a <> "" then
        return a
    end if

    events = client.private.eventProcessor.flush()

    a = m.assertEqual(events.count(), 2)
    if a <> "" then
        return a
    end if

    event = events[1]

    a = m.assertNotInvalid(event)
    if a <> "" then
        return a
    end if

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
        }
    }))
end function

function TestCase__Client_Summary_MultipleFlush() as String
    client = makeTestClientInitialized()

    flagKey = "flag1"
    fallback = "myFallback"
    expectedValue = "expected"

    client.private.store.putAll({
        flag1: {
            value: expectedValue,
            variation: 3,
            version: 4
        }
    })

    client.variation(flagKey, fallback)

    events = client.private.eventProcessor.flush()

    a = m.assertEqual(events.count(), 2)
    if a <> "" then
        return a
    end if

    firstSummary = events[1]

    a = m.assertTrue(firstSummary.endDate >= firstSummary.startDate)
    if a <> "" then
        return a
    end if

    a = m.assertTrue(firstSummary.startDate > 0)
    if a <> "" then
        return a
    end if

    events = client.private.eventProcessor.flush()

    a = m.assertInvalid(events)
    if a <> "" then
        return a
    end if

    client.variation(flagKey, fallback)

    events = client.private.eventProcessor.flush()

    a = m.assertEqual(events.count(), 1)
    if a <> "" then
        return a
    end if

    secondSummary = events[0]

    a = m.assertTrue(secondSummary.startDate >= firstSummary.endDate)
    if a <> "" then
        return a
    end if

    return ""
end function

function TestCase__Client_Track() as String
    client = makeTestClientUninitialized()
    fallback = "fallback"

    eventName = "my-event"
    eventData = {
        a: 2,
        b: 3
    }

    client.track(eventName, eventData, 52)

    eventQueue = client.private.eventProcessor.flush()

    a = m.assertEqual(eventQueue.count(), 2)
    if a <> "" then
        return a
    end if

    event = eventQueue.getEntry(1)

    a = m.assertTrue(event.creationDate > 0)
    if a <> "" then
        return a
    end if
    event.delete("creationDate")

    expected = {
        kind: "custom",
        user: {
            key: "user-key"
        },
        key: eventName,
        data: eventData
    }
    expected["metricValue"] = 52

    return m.assertEqual(FormatJSON(event), FormatJSON(expected))
end function

function TestCase__Client_Identify() as String
    client = makeTestClientUninitialized()

    newUserKey = "user-key2"
    newUser = LaunchDarklyUser(newUserKey)

    client.identify(newUser)

    a = m.assertEqual(client.private.user.private.key, newUserKey)
    if a <> "" then
        return a
    end if

    eventQueue = client.private.eventProcessor.flush()

    a = m.assertEqual(eventQueue.count(), 2)
    if a <> "" then
        return a
    end if

    event = eventQueue.getEntry(1)

    a = m.assertTrue(event.creationDate > 0)
    if a <> "" then
        return a
    end if
    event.delete("creationDate")

    return m.assertEqual(FormatJSON(event), FormatJSON({
        kind: "identify",
        key: "user-key2",
        user: {
            key: "user-key2"
        }
    }))
end function

function testVariation(ctx as Object, functionName as String, flagValue as Dynamic, fallback as Dynamic, expectedValue as Dynamic) as String
    client = makeTestClientInitialized()

    flagKey = "flag1"

    client.private.store.putAll({
        flag1: {
            value: flagValue,
            variation: 3,
            version: 4,
            reason: {
                kind: "FALLTHROUGH"
            }
        }
    })

    actualValue = client[functionName](flagKey, fallback)
    a = ctx.assertEqual(actualValue, expectedValue)
    if a <> "" then
        return a
    end if

    actualValue = client[functionName + "Detail"](flagKey, fallback)
    return ctx.assertEqual(actualValue, {
        result: expectedValue,
        reason: {
            kind: "FALLTHROUGH"
        },
        variationIndex: 3
    })
end function

function TestCase__Client_Variation_Int() as String
    return testVariation(m, "intVariation", 13, 5, 13)
end function

function TestCase__Client_Variation_Bool() as String
    return testVariation(m, "boolVariation", true, false, true)
end function

function TestCase__Client_Variation_String() as String
    return testVariation(m, "stringVariation", "abc", "def", "abc")
end function

function TestCase__Client_Variation_JSONVariationObjectFlag() as String
    return testVariation(m, "jsonVariation", { b: 6 }, { a: 4 }, { b: 6 })
end function

function TestCase__Client_Variation_JSONVariationArrayFlag() as String
    return testVariation(m, "jsonVariation", [1, 2, 3], [4, 5, 6], [1, 2, 3])
end function

function TestCase__Client_Variation_Double() as String
    return testVariation(m, "doubleVariation", 12.5, 6.2, 12.5#)
end function

function TestCase__Client_Variation_DoubleVariationFloatFlag() as String
    return testVariation(m, "doubleVariation", 6.5!, 3, 6.5#)
end function

function TestCase__Client_Variation_IntVariationDoubleFlag() as String
    return testVariation(m, "intVariation", 12.5, 5, 12)
end function

function TestCase__Client_Variation_DoubleVariationIntFlag() as String
    return testVariation(m, "doubleVariation", 6, 3, 6.0#)
end function

function TestCase__Client_VariationDetail_FlagNotFound() as String
    client = makeTestClientInitialized()
    client.private.store.putAll({})

    return m.assertEqual(client.variationDetail("abc", 50), {
        result: 50,
        reason: {
            kind: "ERROR",
            errorKind: "FLAG_NOT_FOUND"
        }
    })
end function

function TestCase__Client_VariationDetail_WrongType() as String
    client = makeTestClientInitialized()

    client.private.store.putAll({
        flag1: {
            value: "hello world!",
            variation: 3,
            version: 4,
            reason: {
                kind: "FALLTHROUGH"
            }
        }
    })

    return m.assertEqual(client.intVariationDetail("flag1", 50), {
        result: 50,
        variationIndex: 3,
        reason: {
            kind: "ERROR",
            errorKind: "WRONG_TYPE"
        }
    })
end function

function TestCase__Client_VariationDetail_ClientNotReady() as String
    client = makeTestClientUninitialized()

    return m.assertEqual(client.variationDetail("abc", 50), {
        result: 50,
        reason: {
            kind: "ERROR",
            errorKind: "CLIENT_NOT_READY"
        }
    })
end function

function TestCase__Client_AllFlags() as String
    client = makeTestClientUninitialized()

    flags = {
        flag1: {
            value: 3
        },
        flag2: {
            value: 5
        }
    }

    client.private.store.putAll(flags)

    allFlags = client.allFlags()

    return m.assertEqual(formatJSON(allFlags), formatJSON({
        flag1: 3,
        flag2: 5
    }))
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
    this.addTest("TestCase__Client_Summary_MultipleFlush", TestCase__Client_Summary_MultipleFlush)
    this.addTest("TestCase__Client_Variation_Int", TestCase__Client_Variation_Int)
    this.addTest("TestCase__Client_Variation_Bool", TestCase__Client_Variation_Bool)
    this.addTest("TestCase__Client_Variation_String", TestCase__Client_Variation_String)
    this.addTest("TestCase__Client_Variation_JSONVariationObjectFlag", TestCase__Client_Variation_JSONVariationObjectFlag)
    this.addTest("TestCase__Client_Variation_JSONVariationArrayFlag", TestCase__Client_Variation_JSONVariationArrayFlag)
    this.addTest("TestCase__Client_Variation_Double", TestCase__Client_Variation_Double)
    this.addTest("TestCase__Client_Variation_DoubleVariationFloatFlag", TestCase__Client_Variation_DoubleVariationFloatFlag)
    this.addTest("TestCase__Client_Variation_IntVariationDoubleFlag", TestCase__Client_Variation_IntVariationDoubleFlag)
    this.addTest("TestCase__Client_Variation_DoubleVariationIntFlag", TestCase__Client_Variation_DoubleVariationIntFlag)
    this.addTest("TestCase__Client_VariationDetail_FlagNotFound", TestCase__Client_VariationDetail_FlagNotFound)
    this.addTest("TestCase__Client_VariationDetail_WrongType", TestCase__Client_VariationDetail_WrongType)
    this.addTest("TestCase__Client_VariationDetail_ClientNotReady", TestCase__Client_VariationDetail_ClientNotReady)
    this.addTest("TestCase__Client_AllFlags", TestCase__Client_AllFlags)

    return this
end function
