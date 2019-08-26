function onFeatureChange() as Void
    v = m.ld.variation("hello-roku", false)
    print "evaluation: " v

    if v then
        m.featureStatus.text = "feature is launched"
    else
        m.featureStatus.text = "feature is hidden"
    end if
end function

function onStatusChange() as Void
    print "status changed"

    status = m.ld.status.getStatusAsString()

    m.clientStatus.text = "client status: " + status
end function

function init() as Void
    launchDarklyNode = m.top.findNode("launchDarkly")

    config = LaunchDarklyConfig("mob-", launchDarklyNode)
    config.setLogLevel(LaunchDarklyLogLevels().debug)
    REM config.setStreaming(false)

    user = LaunchDarklyUser("user-key")

    LaunchDarklySGInit(config, user)

    m.ld = LaunchDarklySG(launchDarklyNode)

    m.featureStatus = m.top.findNode("featureStatus")
    m.featureStatus.font.size=92
    m.featureStatus.color="0x72D7EEFF"

    m.clientStatus = m.top.findNode("clientStatus")

    onStatusChange()
    onFeatureChange()

    launchDarklyNode.observeField("flags", "onFeatureChange")
    launchDarklyNode.observeField("status", "onStatusChange")

end function
