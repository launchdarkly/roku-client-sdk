function makeTestClientUninitialized() as Object
    messagePort = CreateObject("roMessagePort")
    config = LaunchDarklyConfig("mob-abc123")
    config.setOffline(true)
    context = LaunchDarklyCreateContext({key: "user-key", kind: "user"})
    return LaunchDarklyClient(config, context, messagePort)
end function

function makeTestClientInitialized() as Object
    context = LaunchDarklyCreateContext({key: "user-key", kind: "user"})
    config = LaunchDarklyConfig("mob-abc123")
    config.setOffline(true)

    messagePort = CreateObject("roMessagePort")
    client = LaunchDarklyClient(config, context, messagePort)
    client.status.private.setStatus(client.status.map.initialized)
    return client
end function

function assertIdentifyEvent(ctx as Object, event as Object, context as Object) as String
    a = ctx.assertTrue(event.creationDate > 0)
    if a <> "" then
        return a
    end if
    event.delete("creationDate")
    expected = {
        kind: "identify",
        key: context.key(),
        context: {
            key: context.key(),
            kind: context.kind()
        }
    }
    return ctx.assertEqual(FormatJSON(event), FormatJSON(expected))
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
        context: {
            key: "user-key",
            kind: "user"
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
                counters: counters,
                "contextKinds": ["user"]
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
                "contextKinds": ["user"]
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
        key: eventName,
        data: eventData,
        context: {
            key: "user-key",
            kind: "user"
        }
    }

    expected["metricValue"] = 52

    return m.assertEqual(FormatJSON(event), FormatJSON(expected))
end function

function TestCase__Client_Identify() as String
    client = makeTestClientUninitialized()

    newContextKey = "user-key2"
    newContext = LaunchDarklyCreateContext({key: newContextKey, kind: "user"})

    client.identify(newContext)

    a = m.assertEqual(client.private.context.key(), newContextKey)
    if a <> "" then
        return a
    end if

    eventQueue = client.private.eventProcessor.flush()

    a = m.assertEqual(eventQueue.count(), 2)
    if a <> "" then
        return a
    end if

    return assertIdentifyEvent(m, eventQueue.getEntry(1), newContext)
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
            variation: 1,
            version: 100,
        },
        flag2: {
            value: 5,
            variation: 2,
            version: 200,
        }
    }

    client.private.store.putAll(flags)

    allFlagsState = client.allFlagsState()

    r = m.assertTrue(allFlagsState["$valid"])
    if r <> "" then
      return r
    end if

    expected = {
      "$valid": true,
      flag1: 3,
      flag2: 5,
      "$flagsState": {
        flag1: { variation: 1, version: 100 },
        flag2: { variation: 2, version: 200 }
      }
    }

    return m.assertEqual(formatJSON(allFlagsState), formatJSON(expected))
end function

' Cycle-detection tests exercise the ancestor-set cycle guard added to variationDetail.
' Each test constructs a cyclic prereq graph in the store, evaluates one flag on the cycle,
' and asserts (a) the requested flag returns its cached value unchanged and (b) the recorded
' feature events match exactly one entry per cycle-safe descent.

function countFeatureEventsInOrder(events as Object) as Object
    keys = createObject("roArray", 0, true)
    for i = 0 to events.count() - 1
        e = events[i]
        if type(e) = "roAssociativeArray" and e.kind = "feature" then
            keys.push(e.key)
        end if
    end for
    return keys
end function

function TestCase__Client_CycleDetection_SelfLoop() as String
    client = makeTestClientInitialized()
    ' flagA's only prerequisite is itself; the cycle guard skips descent.
    client.private.store.putAll({
        flagA: {
            value: "cached",
            variation: 0,
            version: 1,
            trackEvents: true,
            prerequisites: ["flagA"]
        }
    })

    actualValue = client.variation("flagA", "default")
    a = m.assertEqual(actualValue, "cached")
    if a <> "" then
        return a
    end if

    events = client.private.eventProcessor.flush()
    featureKeys = countFeatureEventsInOrder(events)
    ' Only flagA emits a feature event; the self-prereq is cycle-skipped.
    return m.assertEqual(FormatJSON(featureKeys), FormatJSON(["flagA"]))
end function

function TestCase__Client_CycleDetection_TwoCycleEvaluatingA() as String
    client = makeTestClientInitialized()
    client.private.store.putAll({
        flagA: {value: "cached", variation: 0, version: 1, trackEvents: true, prerequisites: ["flagB"]},
        flagB: {value: "cached", variation: 0, version: 1, trackEvents: true, prerequisites: ["flagA"]}
    })

    actualValue = client.variation("flagA", "default")
    a = m.assertEqual(actualValue, "cached")
    if a <> "" then
        return a
    end if

    events = client.private.eventProcessor.flush()
    featureKeys = countFeatureEventsInOrder(events)
    ' Roku emits the current flag's event before recursing (parent-first), so events
    ' are [A, B]. This diverges from other client SDKs, which emit deepest-first
    ' ([B, A]); tracked in follow-up ticket to align.
    return m.assertEqual(FormatJSON(featureKeys), FormatJSON(["flagA", "flagB"]))
end function

function TestCase__Client_CycleDetection_TwoCycleEvaluatingB() as String
    client = makeTestClientInitialized()
    client.private.store.putAll({
        flagA: {value: "cached", variation: 0, version: 1, trackEvents: true, prerequisites: ["flagB"]},
        flagB: {value: "cached", variation: 0, version: 1, trackEvents: true, prerequisites: ["flagA"]}
    })

    actualValue = client.variation("flagB", "default")
    a = m.assertEqual(actualValue, "cached")
    if a <> "" then
        return a
    end if

    events = client.private.eventProcessor.flush()
    featureKeys = countFeatureEventsInOrder(events)
    ' Symmetric: same graph, entry from B. Parent-first order (see companion test).
    return m.assertEqual(FormatJSON(featureKeys), FormatJSON(["flagB", "flagA"]))
end function

function TestCase__Client_CycleDetection_ThreeCycle() as String
    client = makeTestClientInitialized()
    client.private.store.putAll({
        flagA: {value: "cached", variation: 0, version: 1, trackEvents: true, prerequisites: ["flagB"]},
        flagB: {value: "cached", variation: 0, version: 1, trackEvents: true, prerequisites: ["flagC"]},
        flagC: {value: "cached", variation: 0, version: 1, trackEvents: true, prerequisites: ["flagA"]}
    })

    actualValue = client.variation("flagA", "default")
    a = m.assertEqual(actualValue, "cached")
    if a <> "" then
        return a
    end if

    events = client.private.eventProcessor.flush()
    featureKeys = countFeatureEventsInOrder(events)
    ' A -> B -> C -> [A skipped]. Parent-first ordering yields A, B, C.
    return m.assertEqual(FormatJSON(featureKeys), FormatJSON(["flagA", "flagB", "flagC"]))
end function

function TestCase__Client_CycleDetection_Diamond() as String
    ' Diamond: A -> [B, C], B -> [D], C -> [D]. Not a cycle. Ancestor-set (current-path)
    ' semantics let D be reached on each of the two independent paths, so D emits twice.
    ' A naive "visited across the whole walk" implementation would drop the second event.
    client = makeTestClientInitialized()
    client.private.store.putAll({
        flagA: {value: "cached", variation: 0, version: 1, trackEvents: true, prerequisites: ["flagB", "flagC"]},
        flagB: {value: "cached", variation: 0, version: 1, trackEvents: true, prerequisites: ["flagD"]},
        flagC: {value: "cached", variation: 0, version: 1, trackEvents: true, prerequisites: ["flagD"]},
        flagD: {value: "cached", variation: 0, version: 1, trackEvents: true}
    })

    actualValue = client.variation("flagA", "default")
    a = m.assertEqual(actualValue, "cached")
    if a <> "" then
        return a
    end if

    events = client.private.eventProcessor.flush()
    featureKeys = countFeatureEventsInOrder(events)
    ' Parent-first per path: A, then descend B (emit B, then D), then descend C
    ' (emit C, then D). D emits twice, exercising the per-path (current-path)
    ' ancestor-set semantics vs a global visited set.
    return m.assertEqual(FormatJSON(featureKeys), FormatJSON(["flagA", "flagB", "flagD", "flagC", "flagD"]))
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
    this.addTest("TestCase__Client_CycleDetection_SelfLoop", TestCase__Client_CycleDetection_SelfLoop)
    this.addTest("TestCase__Client_CycleDetection_TwoCycleEvaluatingA", TestCase__Client_CycleDetection_TwoCycleEvaluatingA)
    this.addTest("TestCase__Client_CycleDetection_TwoCycleEvaluatingB", TestCase__Client_CycleDetection_TwoCycleEvaluatingB)
    this.addTest("TestCase__Client_CycleDetection_ThreeCycle", TestCase__Client_CycleDetection_ThreeCycle)
    this.addTest("TestCase__Client_CycleDetection_Diamond", TestCase__Client_CycleDetection_Diamond)

    return this
end function
