sub main(params as object)
    print "in showChannelSGScreen"

    if params.RunTests = "true"
        runner = TestRunner()

        if params.host <> invalid
            runner.logger.SetServer(params.host, params.port)
        else
            runner.logger.SetServerURL(param.url)
        end if

        runner.run()
    else
        screen = createObject("roSGScreen")
        messagePort = createObject("roMessagePort")
        screen.setMessagePort(messagePort)

        scene = screen.CreateScene("AppScene")

        screen.show()

        while (true)
            msg = wait(2500, messagePort)

            if type(msg) = "roSGScreenEvent"
                if msg.isScreenClosed() then
                    return
                end if
            end if
        end while
    end if
end sub
