function TestCase__Config_Constructor()
    config = LaunchDarklyConfig("mob")
    return m.assertEqual(config.private.mobileKey, "mob")
end function

function TestCase__Config_AppURI()
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.appURI, "https://app.launchdarkly.com")
    if a <> "" then
        return a
    end if

    config.setAppURI("https://test.com")

    return m.assertEqual(config.private.appURI, "https://test.com")
end function

function TestCase__Config_PollingInterval()
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.pollingInterval, 15)
    if a <> "" then
        return a
    end if

    config.setPollingInterval(41)

    return m.assertEqual(config.private.pollingInterval, 41)
end function

function TestCase__Config_Offline()
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.offline, false)
    if a <> "" then
        return a
    end if

    config.setOffline(true)

    return m.assertEqual(config.private.offline, true)
end function

function TestCase__Config_EventsCapacity()
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.eventsCapacity, 100)
    if a <> "" then
        return a
    end if

    config.setEventsCapacity(52)

    return m.assertEqual(config.private.eventsCapacity, 52)
end function

function TestCase__Config_EventsFlushInterval()
    config = LaunchDarklyConfig("mob")

    a = m.assertEqual(config.private.eventsCapacity, 100)

    if a <> "" then
        return a
    end if

    config.setEventsFlushInterval(90)

    return m.assertEqual(config.private.eventsFlushInterval, 90)
end function

function TestSuite__Config() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Config"

    this.addTest("TestCase__Config_Constructor", TestCase__Config_Constructor)
    this.addTest("TestCase__Config_AppURI", TestCase__Config_AppURI)
    this.addTest("TestCase__Config_PollingInterval", TestCase__Config_PollingInterval)
    this.addTest("TestCase__Config_Offline", TestCase__Config_Offline)
    this.addTest("TestCase__Config_EventsCapacity", TestCase__Config_EventsCapacity)
    this.addTest("TestCase__Config_FlushInterval", TestCase__Config_EventsFlushInterval)

    return this
end function
