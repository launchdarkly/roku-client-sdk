sub main(params as object)
    print "in showChannelSGScreen"

    if params.RunTests = "true"
        runner = TestRunner()

        runner.SetFunctions([
            TestSuite__Client
            TestSuite__Config
            TestSuite__Context
            TestSuite__Crypto
            TestSuite__HTTP
            TestSuite__SSE
            TestSuite__Store_Memory
            TestSuite__Store_Registry
            TestSuite__Store_Registry_Bypass
            TestSuite__User
            TestSuite__Utility
        ])

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
