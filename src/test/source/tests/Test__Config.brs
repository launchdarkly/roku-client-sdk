function TestCase__Config_Constructor()
    config = LaunchDarklyConfig("mob")
    return m.assertEqual(config.private.mobileKey, "mob")
end function

function TestCase__Config_AppURI_Default()
    config = LaunchDarklyConfig("mob")
    return m.assertEqual(config.private.appURI, "https://app.launchdarkly.com")
end function

function TestCase__Config_AppURI_Setter()
    config = LaunchDarklyConfig("mob")
    config.setAppURI("https://test.com")
    return m.assertEqual(config.private.appURI, "https://test.com")
end function

function TestCase__Config_PollingInterval_Default()
    config = LaunchDarklyConfig("mob")
    return m.assertEqual(config.private.pollingInterval, 15)
end function

function TestCase__Config_PollingInterval_Setter()
    config = LaunchDarklyConfig("mob")
    config.setPollingInterval(41)
    return m.assertEqual(config.private.pollingInterval, 41)
end function

function TestCase__Config_Offline_Default()
    config = LaunchDarklyConfig("mob")
    return m.assertEqual(config.private.offline, false)
end function

function TestCase__Config_Offline_Setter()
    config = LaunchDarklyConfig("mob")
    config.setOffline(true)
    return m.assertEqual(config.private.offline, true)
end function

function TestSuite__Config() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Config"

    this.addTest("TestCase__Config_Constructor", TestCase__Config_Constructor)
    this.addTest("TestCase__Config_AppURI_Default", TestCase__Config_AppURI_Default)
    this.addTest("TestCase__Config_AppURI_Setter", TestCase__Config_AppURI_Setter)
    this.addTest("TestCase__Config_PollingInterval_Default", TestCase__Config_PollingInterval_Default)
    this.addTest("TestCase__Config_PollingInterval_Setter", TestCase__Config_PollingInterval_Setter)
    this.addTest("TestCase__Config_Offline_Default", TestCase__Config_Offline_Default)
    this.addTest("TestCase__Config_Offline_Setter", TestCase__Config_Offline_Setter)

    return this
end function
