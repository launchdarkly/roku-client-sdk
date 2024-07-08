sub main(_params as object)
  print "in showChannelSGScreen"

  screen = createObject("roSGScreen")
  messagePort = createObject("roMessagePort")
  screen.setMessagePort(messagePort)

  _scene = screen.CreateScene("AppScene")

  screen.show()

  while (true)
    msg = wait(2500, messagePort)

    if type(msg) = "roSGScreenEvent"
      if msg.isScreenClosed() then
        return
      end if
    end if
  end while
end sub
