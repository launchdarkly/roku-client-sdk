function onChange() as Void
    v = m.ld.variation("hello-roku", false)
    print "evaluation: " v

    if v then
        m.myLabel.text = "feature is launched"
    else
        m.myLabel.text = "feature is hidden"
    end if
end function

function init() as Void
    launchDarklyNode = m.top.findNode("launchDarkly")

    config = LaunchDarklyConfig("mob-", launchDarklyNode)
    config.setLogLevel(LaunchDarklyLogLevels().debug)

    user = LaunchDarklyUser("user-key")

    LaunchDarklySGInit(config, user)

    m.ld = LaunchDarklySG(launchDarklyNode)

    launchDarklyNode.observeField("flags", "onchange")

    m.myLabel = m.top.findNode("myLabel")
    m.myLabel.font.size=92
    m.myLabel.color="0x72D7EEFF"
end function
