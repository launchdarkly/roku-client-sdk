function init()
    m.messagePort = createObject("roMessagePort")

    m.top.functionName = "mainThread"
    m.top.control = "RUN"
end function

function mainThread() as Void
  port = 9000
  monitor = ServiceMonitor(m.top, port)

  messagePort = CreateObject("roMessagePort")
  server = createHttpServer(messagePort, port, monitor)

  if server = invalid then
    print "failed to create server"
    monitor.setState("failed")
    return
  end if

  monitor.setState("listening")

  while true
    event = wait(0, messagePort)

    if server.handleEvent(event) = false then
      print "unknown message"
    end if
  end while
end function

function createHttpServer(messagePort as Object, port as Integer, monitor as Object) as Object
  socket = CreateObject("roStreamSocket")
  socket.setMessagePort(messagePort)

  addr = CreateObject("roSocketAddress")
  addr.setPort(port)

  socket.setAddress(addr)
  socket.notifyReadable(true)
  socket.listen(10)

  if socket.eOK() = false then
    print "failed to create socket"

    return invalid
  end if

  server = {
    private: {
      contexts: {},
      clients: {},
      buffer: CreateObject("roByteArray"),
      messagePort: messagePort,
      monitor: monitor,
      socket: socket,
    },

    shutdown: false,

    handleEvent: function(paramEvent as Object) as Boolean
      if type(paramEvent) <> "roSocketEvent" then
        return false
      end if

      socketId = paramEvent.getSocketID()

      if socketId = m.private.socket.getID() and m.private.socket.isReadable()
        newConnection = m.private.socket.accept()
        if newConnection = invalid
          print "accept failed"
          return false
        end if

        print "accepted new connection" newConnection.getID()
        newConnection.notifyReadable(true)
        newConnection.setMessagePort(m.private.messagePort)

        localHandler = Handler(m.private.clients, CreateObject("roSGNode", "LaunchDarklyTask"), m.private.monitor)
        m.private.contexts[stri(newConnection.getID())] = ConnectionContext(newConnection, localHandler)

        return true
      end if

      context = m.private.contexts[stri(socketId)]
      closed = false

      if context.connection.isReadable()

        while true
          received = context.connection.receive(m.private.buffer, 0, 1024)

          if received < -1 then
            print "unknown code on receive: " received.toStr()

            closed = true

            exit while
          else if received = -1 then
            exit while
          else if received = 0 then
            print "connection was closed on zero"

            closed = true

            exit while
          else if received > 0 then
            bufferCopy = createObject("roByteArray")
            bufferCopy.setResize(received, false)

            LaunchDarklyUtility().memcpy(m.private.buffer, 0, bufferCopy, 0, received)

            if context.onData(bufferCopy) = false then
              closed = true

              exit while
            end if
          end if
        end while

        if closed or not context.connection.eOK()
          print "closing connection" socketId
          context.connection.close()
          m.private.contexts.delete(stri(socketId))
        end if
      end if
    end function
  }

  server.private.buffer[1024] = 0

  return server
end function

function ConnectionContext(socket as Dynamic, handlerParam as Object) as Object
    return {
        connection: socket,

        request: LaunchDarklyHTTPRequest(),
        handler: handlerParam,

        stageMap: {
            awaitingHeader: 0,
            awaitingBody: 1,
            sendingResponse: 2
        },
        stage: 0,

        body: invalid,
        responseBuffer: createObject("roByteArray"),
        responseBufferSent: 0,

        pollWrite: function() as Boolean
            if m.stage <> m.stageMap.sendingResponse then
                return true
            end if

            while true
                status = m.connection.send(m.responseBuffer, m.responseBufferSent, m.responseBuffer.count() - m.responseBufferSent)

                if status < -1 then
                    print "unknown code on send: " status.toStr()

                    return false
                else if status = -1 then
                    return true
                else if status = 0 then
                    print "connection closed while writing"

                    return false
                end if

                m.responseBufferSent += status

                if m.responseBufferSent = m.responseBuffer.count() then
                    return false
                end if
            end while
        end function,

        onData: function(data as Object) as Boolean
            print "data is: " data.toAsciiString()

            if m.stage = m.stageMap.sendingResponse then
                print "got more incoming bytes when sending request"

                return false
            end if

            m.request.addBytes(data)

            chunk = m.request.streamHTTP()

            if m.request.responseStatus < 0 then
                error = m.streamHTTP.responseStatusText()

                print "http stream: " + error

                return false
            else if m.request.responseStatus >= 1 AND m.stage = m.stageMap.awaitingHeader then
                print "got header with verb " + m.request.requestVerb
                print "got request with path" + m.request.requestPath

                m.stage = m.stageMap.awaitingHeader
            end if

            if chunk <> invalid then
                if m.body = invalid then
                    m.body = createObject("roByteArray")
                end if

                m.body.append(chunk)
            else
                print "http stream got no chunk"
            end if

            if m.request.responseStatus = 2 then
                m.stage = m.stageMap.sendingResponse

                m.responseBuffer = m.handler.dispatch(m.request, m.body)

                return m.pollWrite()
            end if

            return true
        end function
    }
end function


function Handler(clients as Object, launchDarklyNode as Object, monitor as Object) as Object
    return {
        private: {
          clientIndex: 0,
          clients: clients
          launchDarklyNode: launchDarklyNode
          monitor: monitor,
          lastStatus: 0,
          lastMessage: ""
        },

        shutdown: false,

        makeResponse: function(responseCode as Integer, responseText as String, responseBody as Dynamic, locationHeader = "" as String) as Object
            m.private.lastStatus = responseCode
            if responseCode >= 400 and responseBody <> invalid and getInterface(responseBody, "ifString") <> invalid then
                m.private.lastMessage = responseBody
            end if

            response = ""
            response += "HTTP/1.1 " + responseCode.toStr() + " " + responseText + chr(13) + chr(10)
            response += "Connection: close" + chr(13) + chr(10)

            responseBodyBuffer = invalid

            if responseBody <> invalid then
                contentType = ""

                if getInterface(responseBody, "ifString") <> invalid then
                    contentType = "text/plain"
                    responseBodyBuffer = createObject("roByteArray")
                    responseBodyBuffer.fromAsciiString(responseBody)
                else if getInterface(responseBody, "ifAssociativeArray") <> invalid then
                    contentType = "application/json"
                    responseBodyBuffer = createObject("roByteArray")
                    responseBodyBuffer.fromAsciiString(formatJSON(responseBody))
                else
                    print "makeResponse unknown type"

                    STOP
                end if

                response += "Content-Type: " + contentType + chr(13) + chr(10)
                response += "Content-Length: " + responseBodyBuffer.count().toStr() + chr(13) + chr(10)
            end if

            if locationHeader <> invalid and locationHeader <> "" then
                response += locationHeader + chr(13) + chr(10)
            end if

            response += chr(13) + chr(10)

            responseBuffer = createObject("roByteArray")
            responseBuffer.fromAsciiString(response)

            if responseBodyBuffer <> invalid then
                responseBuffer.append(responseBodyBuffer)
            end if

            return responseBuffer
        end function,

        identify: function(client as Object, requestBody as Object) as Object
            context = m.getContext(requestBody)

            if context = invalid then
                return m.makeResponse(400, "Bad Request", "expected context or user in body")
            end if

            client.identify(context)
            m.waitForInitialized(client)

            return invalid
        end function,

        getContext: function(request as Object, contextKey = "context" as String, userKey = "user" as String) as Object
          context = request[contextKey]
          if context <> invalid then
            return LaunchDarklyCreateContext(context)
          end if

          return LaunchDarklyCreateContext(request[userKey])
        end function,

        handle404: function() as Object
            print "called handle404"

            return m.makeResponse(404, "Not Found", "This is not a valid route")
        end function,

        handleStatus: function() as Object
            print "called handleStatus"

            status = {}
            status["clientVersion"] = LaunchDarklySDKVersion()
            status["capabilities"] = [
              "mobile",
              "client-side",
              "singleton",
              "strongly-typed",
              "tags",
              "user-type",
              "inline-context-all",
              "anonymous-redaction",
              "client-prereq-events",
              "client-prereq-cycle-detection",
              "polling-gzip",
            ]

            ' The test harness uses the Roku handshake flow when "roku" is
            ' present. The native stream client uses the standard mobile flow.
            if LaunchDarklyNativeStreamSupported() = false then
              status["capabilities"].push("roku")
            end if

            return m.makeResponse(200, "OK", status)
        end function,

        createClient: function(jsonBody as Object) as Object
          if jsonBody = invalid then
            return m.makeResponse(400, "Bad Request", "expected a post body")
          end if

          m.private.monitor.setCurrentTest(jsonBody["tag"])

          configuration = jsonBody["configuration"]
          config = LaunchDarklyConfig(configuration["credential"], m.private.launchDarklyNode)
          config.private.forcePlainTextInStream = true
          config.setLogLevel(LaunchDarklyLogLevels().debug)

          clientSide = configuration["clientSide"]

          initialContext = m.getContext(clientSide, "initialContext", "initialUser")
          if initialContext = invalid then
            return m.makeResponse(400, "Bad Request", "invalid context or user")
          end if

          if clientSide["evaluationReasons"] <> invalid then
            config.setUseEvaluationReasons(clientSide["evaluationReasons"])
          endif

          streaming = configuration["streaming"]
          polling = configuration["polling"]

          if streaming <> invalid then
            if streaming["baseUri"] <> invalid then
              config.setStreamURI(streaming["baseUri"])
            end if
          else if polling <> invalid then
            config.setStreaming(false)

            if polling["baseUri"] <> invalid then
              config.setAppURI(polling["baseUri"])
            end if

            if polling["pollIntervalMs"] <> invalid then
              config.setPollingIntervalSeconds(polling["pollIntervalMs"] / 1000)
            endif
          end if

          events = configuration["events"]
          if events <> invalid then
            if events["baseUri"] <> invalid then
              config.setEventsURI(events["baseUri"])
            end if

            if events["capacity"] <> invalid then
              config.setEventsCapacity(events["capacity"])
            end if

            if events["flushIntervalMs"] <> invalid then
              config.setEventsFlushIntervalSeconds(events["flushIntervalMs"] / 1000)
            end if

            if events["allAttributesPrivate"] <> invalid then
              config.setAllAttributesPrivate(events["allAttributesPrivate"])
            end if

            if events["globalPrivateAttributes"] <> invalid then
              for each attribute in events["globalPrivateAttributes"]
                config.addPrivateAttribute(attribute)
              end for
            end if
          end if

          tags = configuration["tags"]
          if tags <> invalid then
            applicationId = tags["applicationId"]
            applicationVersion = tags["applicationVersion"]

            if applicationId <> invalid then
              config.setApplicationInfoValue("id", applicationId)
            end if

            if applicationVersion <> invalid then
              config.setApplicationInfoValue("version", applicationVersion)
            end if
          end if

          LaunchDarklySGInit(config, initialContext)
          m.private.clientIndex += 1
          client = LaunchDarklySG(m.private.launchDarklyNode)
          m.private.clients[m.private.clientIndex.toStr()] = client
          m.private.monitor.clientCreated()

          m.waitForInitialized(client)

          return m.makeResponse(200, "OK", invalid, "Location: /client/" + m.private.clientIndex.toStr())
        end function,

        sendCommand: function(client as Object, jsonBody as Object) as Object
          print "called sendCommand"
          command = jsonBody["command"]

          if command = "evaluate" then
            return m.evaluate(client, jsonBody["evaluate"])
          else if command = "evaluateAll" then
            return m.evaluateAll(client, jsonBody["evaluateAll"])
          else if command = "identifyEvent" then
            result = m.identify(client, jsonBody["identifyEvent"])
            if result <> invalid then
              return result
            end if
            return m.makeResponse(200, "OK", "")
          else if command = "customEvent" then
            return m.customEvent(client, jsonBody["customEvent"])
          else if command = "flushEvents" then
            client.flush()
            return m.makeResponse(200, "OK", "")
          endif
        end function,

        evaluate: function(client as Object, params as Object) as Object
          print "called evaluate"

          result = {}
          valueType = params["valueType"]

          if params["detail"] = true then
            detail = invalid
            if valueType = "bool" then
              detail = client.boolVariationDetail(params["flagKey"], params["defaultValue"])
            else if valueType = "int" then
              detail = client.intVariationDetail(params["flagKey"], params["defaultValue"])
            else if valueType = "double" then
              detail = client.doubleVariationDetail(params["flagKey"], params["defaultValue"])
            else if valueType = "string" then
              detail = client.stringVariationDetail(params["flagKey"], params["defaultValue"])
            else if valueType = "any" then
              detail = client.variationDetail(params["flagKey"], params["defaultValue"])
            end if

            if detail <> invalid then
              result["value"] = detail.result
              result["variationIndex"] = detail.variationIndex
              result["reason"] = detail.reason
            end if
          else
            if valueType = "bool" then
              result["value"] = client.boolVariation(params["flagKey"], params["defaultValue"])
            else if valueType = "int" then
              result["value"] = client.intVariation(params["flagKey"], params["defaultValue"])
            else if valueType = "double" then
              result["value"] = client.doubleVariation(params["flagKey"], params["defaultValue"])
            else if valueType = "string" then
              result["value"] = client.stringVariation(params["flagKey"], params["defaultValue"])
            else if valueType = "any" then
              result["value"] = client.variation(params["flagKey"], params["defaultValue"])
            end if
          end if

          return m.makeResponse(200, "OK", result)
        end function,

        evaluateAll: function(client as Object, _params as Object) as Object
          result = {
            state: client.allFlagsState()
          }
          return m.makeResponse(200, "OK", result)
        end function,

        waitForInitialized: function(client as Object)
          print "waiting on status"
          while client.status.getStatus() <> client.status.map.initialized
          end while
          print "done waiting on status"
        end function,

        customEvent: function(client as Object, params as Object) as Object
          client.track(params["eventKey"], params["data"], params["metricValue"])
          return m.makeResponse(200, "OK", "")
        end function,

        formatSingleAsContext: function(payload as Object) as Object
          output = {}
          if payload["custom"] <> invalid then
            output = payload["custom"]
          end if

          if payload.DoesExist("kind") then
            output["kind"] = payload["kind"]
          else
            output["kind"] = "user"
          end if

          if payload["key"] <> invalid then
            output["key"] = payload["key"]
          end if

          if payload["name"] <> invalid then
            output["name"] = payload["name"]
          end if

          if payload["anonymous"] <> invalid then
            output["anonymous"] = payload["anonymous"]
          end if

          if payload["private"] <> invalid then
            output["_meta"] = {"privateAttributes": payload["private"]}
          end if

          return output
        end function,

        clientRegex: CreateObject("roRegex", "/client/([0-9]+)", ""),

        ' Dispatch a request and report it to the on-screen monitor.
        dispatch: function(request as Object, requestBody as Object) as Object
            monitor = m.private.monitor
            m.private.lastStatus = 0
            m.private.lastMessage = ""

            parsedBody = invalid
            if requestBody <> invalid then
                ' if there is a body, it must be JSON
                parsedBody = parseJSON(requestBody.toAsciiString())
            end if

            monitor.startRequest(request.requestVerb, request.requestPath, m.describe(request, parsedBody))

            if requestBody <> invalid and parsedBody = invalid then
                response = m.makeResponse(400, "Bad Request", "failed to parse JSON body")
            else
                response = m.route(request, parsedBody)
            end if

            monitor.finishRequest(m.private.lastStatus, m.private.lastMessage, m.private.clients.count())

            return response
        end function,

        ' Make a short, readable summary of a request for the monitor.
        describe: function(request as Object, body as Object) as String
            verb = request.requestVerb

            if request.requestPath = "/" then
                if verb = "GET" then return "status check"
                if verb = "DELETE" then return "end of test run"
                if verb <> "POST" then return ""

                mode = "streaming"
                if body <> invalid and body["configuration"] <> invalid then
                    configuration = body["configuration"]
                    if configuration["streaming"] = invalid and configuration["polling"] <> invalid then
                        mode = "polling"
                    end if
                end if

                return "create client (" + mode + ")"
            end if

            if verb = "DELETE" then return "delete client"
            if body = invalid then return ""

            command = body["command"]
            if command = "evaluate" then
                params = body["evaluate"]
                if params = invalid then return "evaluate"

                label = "evaluate"
                detail = params["detail"]
                if detail <> invalid and detail then
                    label = "evaluate detail"
                end if

                return label + " " + monitorText(params["valueType"]) + " " + monitorText(params["flagKey"])
            else if command = "evaluateAll" then
                return "evaluate all"
            else if command = "identifyEvent" then
                return "identify"
            else if command = "customEvent" then
                params = body["customEvent"]
                if params = invalid then return "track"

                return "track " + monitorText(params["eventKey"])
            else if command = "flushEvents" then
                return "flush events"
            end if

            return monitorText(command)
        end function,

        route: function(request as Object, parsedBody as Object) as Object
            if request.requestVerb = "GET" AND request.requestPath = "/" then
                return m.handleStatus()
            else if request.requestVerb = "DELETE" AND request.requestPath = "/" then
              m.private.monitor.setState("finished")
              return m.makeResponse(200, "OK", "shutdown request")
              ' TODO: implement server shutdown
            else if request.requestVerb = "POST" AND request.requestPath = "/" then
              return m.createClient(parsedBody)
            end if

            '
            ' Start matching client specific routes (e.g. POST|DELETE /client/1)
            '

            match = m.clientRegex.Match(request.requestPath)
            if match.Count() <> 2 then
              return m.handle404()
            end if

            if request.requestVerb = "DELETE"
              client = m.private.clients[match[1]]
              if client <> invalid then
                client.private.clientNode.control = "STOP"
                m.private.clients.delete(match[1])
                client = invalid
              end if

              return m.makeResponse(200, "OK", "deleted")
            end if

            if request.requestVerb = "POST"
              client = m.private.clients[match[1]]
              if client = invalid then
                return m.makeResponse(400, "Bad Request", "requested client not found")
              end if

              return m.sendCommand(client, parsedBody)
            end if

            return m.handle404()
        end function
    }
end function

' Return a value as display text. Return "?" for a value that is not a string.
function monitorText(value as Dynamic) as String
    if value <> invalid and getInterface(value, "ifString") <> invalid then
        return value
    end if

    return "?"
end function

' Collect service activity and publish it to the task "dashboard" field.
' The scene observes that field and draws the status screen.
function ServiceMonitor(node as Object, port as Integer) as Object
    monitor = {
        node: node,
        port: port,
        maxEntries: 8,
        clock: CreateObject("roTimespan"),
        snapshot: invalid,

        now: function() as Integer
            return CreateObject("roDateTime").asSeconds()
        end function,

        reset: function(state as String) as Void
            m.snapshot = {
                state: state,
                port: m.port,
                sdkVersion: LaunchDarklySDKVersion(),
                startedAt: m.now(),
                lastRequestAt: 0,
                requests: 0,
                errors: 0,
                clientsCreated: 0,
                activeClients: 0,
                currentTest: "",
                inFlight: invalid,
                entries: []
            }
            m.publish()
        end function,

        setState: function(state as String) as Void
            m.snapshot.state = state
            m.publish()
        end function,

        setCurrentTest: function(tag as Dynamic) as Void
            if tag <> invalid then
                m.snapshot.currentTest = monitorText(tag)
            end if
            m.publish()
        end function,

        clientCreated: function() as Void
            m.snapshot.clientsCreated += 1
            m.publish()
        end function,

        startRequest: function(verb as String, path as String, summary as String) as Void
            ' The harness checks the service status at the start of each run.
            ' A status check after a finished run starts a new set of counters.
            if verb = "GET" and path = "/" and m.snapshot.state = "finished" then
                m.reset("listening")
            end if

            ' The first request of a run starts the run time.
            if m.snapshot.state = "listening" then
                m.snapshot.state = "running"
                m.snapshot.startedAt = m.now()
            end if

            m.clock.mark()
            m.snapshot.inFlight = {
                time: m.now(),
                method: verb,
                path: path,
                summary: summary
            }
            m.publish()
        end function,

        finishRequest: function(status as Integer, message as String, activeClients as Integer) as Void
            entry = m.snapshot.inFlight
            entry.status = status
            entry.message = message
            entry.durationMs = m.clock.totalMilliseconds()

            m.snapshot.requests += 1
            if status = 0 or status >= 400 then
                m.snapshot.errors += 1
            end if

            m.snapshot.activeClients = activeClients
            m.snapshot.lastRequestAt = m.now()
            m.snapshot.inFlight = invalid

            m.snapshot.entries.unshift(entry)
            if m.snapshot.entries.count() > m.maxEntries then
                m.snapshot.entries.pop()
            end if

            m.publish()
        end function,

        publish: function() as Void
            m.node.dashboard = m.snapshot
        end function
    }

    monitor.reset("starting")

    return monitor
end function
