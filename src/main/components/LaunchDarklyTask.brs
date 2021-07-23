function init()
    m.messagePort = createObject("roMessagePort")
    m.top.flags = {}

    m.top.observeField("event", m.messagePort)
    m.top.observeField("log", m.messagePort)
    m.top.observeField("flush", m.messagePort)
    m.top.observeField("user", m.messagePort)
    m.top.observeField("track", m.messagePort)
    m.top.observeField("alias", m.messagePort)
    m.top.observeField("config", "startThread")
end function

function startThread() as Void
    m.top.functionName = "mainThread"
    m.top.control = "RUN"
end function

function mainThread() as Void
    user = m.top.user
    config = m.top.config

    loggerBackend = invalid
    if m.top.isSameNode(config.private.loggerNode) then
        loggerBackend = LaunchdarklyLoggerPrint()
    else
        loggerBackend = LaunchDarklyLoggerSG(config.private.loggerNode)
    end if

    config.private.logger = LaunchDarklyLogger(config, loggerBackend)
    store = LaunchDarklyStoreSG(config.private.storeBackendNode)
    config.private.storeBackend = store

    client = LaunchDarklyClient(config, user, m.messagePort)

    while (true)
        msg = wait(3000, m.messagePort)

        client.handleMessage(msg)

        if type(msg) = "roSGNodeEvent" then
            field = msg.getField()
            if field = "event" then
                client.private.handleEventsForEval(msg.getData())
            else if field = "log" then
                value = msg.getData()
                loggerBackend.log(value.level, value.message)
            else if field = "flush" then
                client.flush()
            else if field = "user" then
                user = msg.getData()
                REM don't call identify for first user
                if user.private.initial <> true then
                    client.identify(user)
                end if
            else if field = "track" then
                value = msg.getData()
                client.track(value.key, value.data, value.metric)
            else if field = "alias" then
                value = msg.getData()
                client.alias(value.user, value.previousUser)            
            end if
        end if
    end while
end function
