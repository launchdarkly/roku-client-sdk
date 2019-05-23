sub main(params as object)
    print "in showChannelSGScreen"

    screen = createObject("roSGScreen")
    messagePort = createObject("roMessagePort")
    screen.setMessagePort(messagePort)

    screen.show()

    if params.RunTests = "true"
        runner = TestRunner()

        if params.host <> invalid
            runner.logger.SetServer(params.host, params.port)
        else
            runner.logger.SetServerURL(param.url)
        end if

        runner.run()
    end if

    logger = LaunchDarklyLogger(LaunchDarklyLoggerPrint())
    logger.setLogLevel(logger.levels.debug)

    config = LaunchDarklyConfig("mob-")
    config.setAppURI("https://app.ld.catamorphic.com")
    config.setEventsURI("https://events.ld.catamorphic.com")
    config.setLogger(logger)

    user = LaunchDarklyUser("user-key")

    client = LaunchDarklyClient(config, user, messagePort)

    while (true)
        msg = wait(2500, messagePort)

        client.handleMessage(msg)

        print "evaluation: " client.variation("hello-c-client-side", false)

        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then
                return
            end if
        end if
    end while
end sub
