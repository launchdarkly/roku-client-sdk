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

    myLogger = LaunchDarklyLogger(LaunchDarklyLoggerPrint())
    myLogger.setLogLevel(myLogger.levels.debug)

    config = LaunchDarklyConfig("mob-")
    config.setAppURI("https://ld-stg.launchdarkly.com")
    config.setEventsURI("https://events-stg.launchdarkly.com")
    config.setStreamURI("http://192.168.8.139:3400")
    config.setLogger(myLogger)

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
