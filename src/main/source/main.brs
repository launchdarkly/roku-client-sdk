sub main(params as object)
    print "in showChannelSGScreen"

    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

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


    while (true)
      msg = wait(2500, m.port)

      if type(msg) = "roSGScreenEvent"
          if msg.isScreenClosed() then return
      end if
    end while
end sub
