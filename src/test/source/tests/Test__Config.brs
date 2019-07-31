function TestCase__Config_Constructor() as String
    config = LaunchDarklyConfig("mob")
    return m.assertEqual(config.private.mobileKey, "mob")
end function

function TestCase__Config_AppURI() as String
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.appURI, "https://app.launchdarkly.com")
    if a <> "" then
        return a
    end if

    config.setAppURI("https://test.com")

    return m.assertEqual(config.private.appURI, "https://test.com")
end function

function TestCase__Config_EventsURI() as String
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.eventsURI, "https://mobile.launchdarkly.com")
    if a <> "" then
        return a
    end if

    config.setEventsURI("https://test.com")

    return m.assertEqual(config.private.eventsURI, "https://test.com")
end function

function TestCase__Config_PollingIntervalSeconds() as String
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.pollingIntervalSeconds, 15)
    if a <> "" then
        return a
    end if

    config.setPollingIntervalSeconds(41)

    return m.assertEqual(config.private.pollingIntervalSeconds, 41)
end function

function TestCase__Config_Offline() as String
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.offline, false)
    if a <> "" then
        return a
    end if

    config.setOffline(true)

    return m.assertEqual(config.private.offline, true)
end function

function TestCase__Config_AllAttributesPrivate() as String
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.allAttributesPrivate, false)
    if a <> "" then
        return a
    end if

    config.setAllAttributesPrivate(true)

    return m.assertEqual(config.private.allAttributesPrivate, true)
end function

function TestCase__Config_EventsCapacity() as String
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.eventsCapacity, 100)
    if a <> "" then
        return a
    end if

    config.setEventsCapacity(52)

    return m.assertEqual(config.private.eventsCapacity, 52)
end function

function TestCase__Config_EventsFlushIntervalSeconds() as String
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.eventsFlushIntervalSeconds, 30)

    if a <> "" then
        return a
    end if

    config.setEventsFlushIntervalSeconds(90)

    return m.assertEqual(config.private.eventsFlushIntervalSeconds, 90)
end function

function TestCase__Config_Streaming() as String
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.streaming, true)

    if a <> "" then
        return a
    end if

    config.setStreaming(false)

    return m.assertEqual(config.private.streaming, false)
end function

function TestCase__Config_URI_Validation() as String
    config = LaunchDarklyConfig("mob")

    a = m.assertTrue(config.setAppURI("https://test.com"))
    if a <> "" then
        return a
    end if

    a = m.assertTrue(config.setAppURI("http://test.com"))
    if a <> "" then
        return a
    end if

    return m.assertFalse(config.setAppURI("test.com"))
end function


function TestSuite__Config() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Config"

    this.addTest("TestCase__Config_Constructor", TestCase__Config_Constructor)
    this.addTest("TestCase__Config_AppURI", TestCase__Config_AppURI)
    this.addTest("TestCase__Config_EventsURI", TestCase__Config_EventsURI)
    this.addTest("TestCase__Config_PollingIntervalSeconds", TestCase__Config_PollingIntervalSeconds)
    this.addTest("TestCase__Config_Offline", TestCase__Config_Offline)
    this.addTest("TestCase__Config_AllAttributesPrivate", TestCase__Config_AllAttributesPrivate)
    this.addTest("TestCase__Config_EventsCapacity", TestCase__Config_EventsCapacity)
    this.addTest("TestCase__Config_FlushIntervalSeconds", TestCase__Config_EventsFlushIntervalSeconds)
    this.addTest("TestCase__Config_Streaming", TestCase__Config_Streaming)
    this.addTest("TestCase__Config_URI_Validation", TestCase__Config_URI_Validation)

    return this
end function
