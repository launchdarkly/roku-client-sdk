sub main(params as object)
    print "in showChannelSGScreen"

    screen = createObject("roSGScreen")
    port = createObject("roMessagePort")
    screen.setMessagePort(port)

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

    config = LaunchDarklyConfig("mob-")
    config.setAppURI("https://app.ld.catamorphic.com")
    user = LaunchDarklyUser("user-key")
    client = LaunchDarklyClient(config, user, port)

    while (true)
        msg = wait(2500, port)

        client.handleMessage(msg)

        print "evaluation: " client.variation("hello-c-client-side", false)

        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then
                return
            end if
        end if
    end while
end sub
