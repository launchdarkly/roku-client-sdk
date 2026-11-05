' Status screen for the contract test service.
' The HttpServerTask publishes a snapshot of its activity to its "dashboard"
' field. This scene draws that snapshot and refreshes the timers each second.

function init() as Void
    m.colors = {
        background: "0x0E1116FF",
        panel: "0x1A1F27FF",
        brand: "0xEBFF38FF",
        text: "0xE6E6E6FF",
        muted: "0x8B949EFF",
        ok: "0x3FB950FF",
        warn: "0xD29922FF",
        error: "0xF85149FF",
        idle: "0x484F58FF"
    }

    m.snapshot = invalid
    m.ipAddress = deviceIPAddress()

    buildLayout()

    m.server = m.top.findNode("httpServerTask")
    m.server.observeField("dashboard", "onDashboard")

    ' The task can publish before the observer exists. Draw what it has now.
    onDashboard()

    m.ticker = m.top.createChild("Timer")
    m.ticker.repeat = true
    m.ticker.duration = 1
    m.ticker.observeField("fire", "refreshTimers")
    m.ticker.control = "start"
end function

function buildLayout() as Void
    addRect(m.top, 0, 0, 1280, 720, m.colors.background)

    ' Header
    addRect(m.top, 0, 0, 1280, 72, m.colors.panel)
    addLabel(m.top, 40, 0, 700, 72, 32, true, m.colors.brand, "LaunchDarkly Roku SDK")
    m.versionLabel = addLabel(m.top, 640, 0, 600, 72, 22, false, m.colors.muted, "Contract test service")
    m.versionLabel.horizAlign = "right"

    ' Service address and state
    addLabel(m.top, 40, 88, 800, 28, 20, false, m.colors.muted, "Test harness URL")
    m.urlLabel = addLabel(m.top, 40, 114, 900, 52, 40, true, m.colors.text, "")

    m.stateRect = addRect(m.top, 980, 102, 260, 56, m.colors.idle)
    m.stateLabel = addLabel(m.stateRect, 0, 0, 260, 56, 24, true, "0xFFFFFFFF", "")
    m.stateLabel.horizAlign = "center"

    ' Counter tiles
    m.tiles = {}
    tileNames = ["runTime", "requests", "clientsCreated", "activeClients", "errors"]
    tileCaptions = ["Run time", "Requests", "Clients created", "Active clients", "Service errors"]
    for i = 0 to tileNames.count() - 1
        x = 40 + i * 244
        addRect(m.top, x, 184, 224, 92, m.colors.panel)
        value = addLabel(m.top, x + 16, 190, 192, 50, 36, true, m.colors.text, "0")
        addLabel(m.top, x + 16, 238, 192, 28, 18, false, m.colors.muted, tileCaptions[i])
        m.tiles[tileNames[i]] = value
    end for

    ' Current test and the request in progress
    addLabel(m.top, 40, 292, 400, 26, 18, false, m.colors.muted, "Current test")
    m.testLabel = addLabel(m.top, 40, 316, 1200, 60, 22, false, m.colors.text, "")
    m.testLabel.wrap = true
    m.testLabel.maxLines = 2
    m.testLabel.vertAlign = "top"

    m.activityLabel = addLabel(m.top, 40, 380, 1200, 32, 22, false, m.colors.muted, "")

    ' Recent requests, newest first
    addLabel(m.top, 40, 420, 400, 26, 18, false, m.colors.muted, "Recent requests")
    m.rows = []
    for i = 0 to 7
        y = 448 + i * 33
        row = {
            time: addLabel(m.top, 40, y, 110, 30, 20, false, m.colors.muted, ""),
            status: addLabel(m.top, 150, y, 60, 30, 20, true, m.colors.text, ""),
            request: addLabel(m.top, 210, y, 230, 30, 20, false, m.colors.text, ""),
            duration: addLabel(m.top, 440, y, 90, 30, 20, false, m.colors.muted, ""),
            summary: addLabel(m.top, 540, y, 700, 30, 20, false, m.colors.text, "")
        }
        row.duration.horizAlign = "right"
        m.rows.push(row)
    end for
end function

function onDashboard() as Void
    snapshot = m.server.dashboard
    if snapshot = invalid or snapshot.state = invalid then
        return
    end if

    m.snapshot = snapshot

    m.versionLabel.text = "Contract test service  |  SDK " + snapshot.sdkVersion
    m.urlLabel.text = "http://" + m.ipAddress + ":" + snapshot.port.toStr()

    m.tiles.requests.text = snapshot.requests.toStr()
    m.tiles.clientsCreated.text = snapshot.clientsCreated.toStr()
    m.tiles.activeClients.text = snapshot.activeClients.toStr()
    m.tiles.errors.text = snapshot.errors.toStr()
    if snapshot.errors > 0 then
        m.tiles.errors.color = m.colors.error
    else
        m.tiles.errors.color = m.colors.text
    end if

    if snapshot.currentTest = "" then
        m.testLabel.text = "None yet"
        m.testLabel.color = m.colors.muted
    else
        m.testLabel.text = snapshot.currentTest
        m.testLabel.color = m.colors.text
    end if

    drawState(snapshot.state)
    drawEntries(snapshot.entries)
    refreshTimers()
end function

function drawState(state as String) as Void
    if state = "starting" then
        m.stateLabel.text = "Starting"
        m.stateRect.color = m.colors.idle
    else if state = "listening" then
        m.stateLabel.text = "Waiting for harness"
        m.stateRect.color = m.colors.warn
    else if state = "running" then
        m.stateLabel.text = "Test run active"
        m.stateRect.color = m.colors.ok
    else if state = "finished" then
        m.stateLabel.text = "Run finished"
        m.stateRect.color = m.colors.idle
    else if state = "failed" then
        m.stateLabel.text = "Cannot listen"
        m.stateRect.color = m.colors.error
    end if
end function

function drawEntries(entries as Object) as Void
    for i = 0 to m.rows.count() - 1
        row = m.rows[i]
        entry = entries[i]

        if entry = invalid then
            row.time.text = ""
            row.status.text = ""
            row.request.text = ""
            row.duration.text = ""
            row.summary.text = ""
        else
            failed = entry.status = 0 or entry.status >= 400

            row.time.text = clockTime(entry.time)
            row.status.text = entry.status.toStr()
            row.request.text = entry.method + " " + entry.path
            row.duration.text = formatMilliseconds(entry.durationMs)

            summary = entry.summary
            if failed and entry.message <> "" then
                summary = summary + " -- " + entry.message
            end if
            row.summary.text = summary

            if failed then
                row.status.color = m.colors.error
                row.summary.color = m.colors.error
            else
                row.status.color = m.colors.ok
                row.summary.color = m.colors.text
            end if
        end if
    end for
end function

' Update the values that change with time even when no request arrives.
function refreshTimers() as Void
    snapshot = m.snapshot
    if snapshot = invalid then
        return
    end if

    now = CreateObject("roDateTime").asSeconds()
    if snapshot.state = "starting" or snapshot.state = "listening" then
        m.tiles.runTime.text = "--"
    else
        m.tiles.runTime.text = formatSeconds(now - snapshot.startedAt)
    end if

    inFlight = snapshot.inFlight
    if inFlight <> invalid then
        elapsed = now - inFlight.time
        m.activityLabel.text = "Handling " + inFlight.method + " " + inFlight.path + "  " + inFlight.summary + "  (" + formatSeconds(elapsed) + ")"
        ' A request that takes this long usually means the SDK is stuck.
        if elapsed >= 5 then
            m.activityLabel.color = m.colors.warn
        else
            m.activityLabel.color = m.colors.text
        end if
    else if snapshot.lastRequestAt > 0 then
        m.activityLabel.text = "Idle for " + formatSeconds(now - snapshot.lastRequestAt)
        m.activityLabel.color = m.colors.muted
    else
        m.activityLabel.text = "No requests yet"
        m.activityLabel.color = m.colors.muted
    end if
end function

function deviceIPAddress() as String
    addresses = CreateObject("roDeviceInfo").getIPAddrs()
    for each name in addresses
        return addresses[name]
    end for

    return "no-network"
end function

function addRect(parent as Object, x as Integer, y as Integer, width as Integer, height as Integer, color as String) as Object
    rect = parent.createChild("Rectangle")
    rect.translation = [x, y]
    rect.width = width
    rect.height = height
    rect.color = color
    return rect
end function

function addLabel(parent as Object, x as Integer, y as Integer, width as Integer, height as Integer, size as Integer, bold as Boolean, color as String, text as String) as Object
    font = CreateObject("roSGNode", "Font")
    if bold then
        font.uri = "font:BoldSystemFontFile"
    else
        font.uri = "font:SystemFontFile"
    end if
    font.size = size

    label = parent.createChild("Label")
    label.translation = [x, y]
    label.width = width
    label.height = height
    label.font = font
    label.color = color
    label.vertAlign = "center"
    label.text = text
    return label
end function

function padTwo(value as Integer) as String
    if value < 10 then
        return "0" + value.toStr()
    end if

    return value.toStr()
end function

function clockTime(seconds as Integer) as String
    dt = CreateObject("roDateTime")
    dt.fromSeconds(seconds)
    dt.toLocalTime()
    return padTwo(dt.getHours()) + ":" + padTwo(dt.getMinutes()) + ":" + padTwo(dt.getSeconds())
end function

function formatSeconds(seconds as Integer) as String
    if seconds < 60 then
        return seconds.toStr() + "s"
    else if seconds < 3600 then
        return (seconds \ 60).toStr() + "m " + padTwo(seconds mod 60) + "s"
    end if

    return (seconds \ 3600).toStr() + "h " + padTwo((seconds mod 3600) \ 60) + "m"
end function

function formatMilliseconds(milliseconds as Integer) as String
    if milliseconds < 1000 then
        return milliseconds.toStr() + " ms"
    end if

    return (milliseconds \ 1000).toStr() + "." + ((milliseconds mod 1000) \ 100).toStr() + " s"
end function
