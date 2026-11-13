function makeTestNativeStreamClient(context as Object) as Object
    client = makeTestClientUninitialized()
    return LaunchDarklyNativeStreamClient(client.private.config, client.private.store, CreateObject("roMessagePort"), context, client.status)
end function

function nativeStreamFakeTransfer() as Object
    return {
        cancelled: false,
        getIdentity: function() as Integer
            return 4242
        end function,
        asyncCancel: function() as Void
            m.cancelled = true
        end function
    }
end function

function nativeStreamFakeUrlEvent(kind as Integer, code as Integer) as Object
    return {
        kind: kind,
        code: code,
        getInt: function() as Integer
            return m.kind
        end function,
        getResponseCode: function() as Integer
            return m.code
        end function,
        getFailureReason: function() as String
            return "test"
        end function,
        getSourceIdentity: function() as Integer
            return 4242
        end function
    }
end function

function nativeStreamFakeNetworkEvent(info as Object) as Object
    return {
        info: info,
        isStatusMessage: function() as Boolean
            return true
        end function,
        getInfo: function() as Object
            return m.info
        end function
    }
end function

function TestCase__NativeStream_URLUsesURLSafeBase64() as String
    ' This key encodes to base64 that contains "+" and "/".
    context = LaunchDarklyCreateContext({key: "???>>>", kind: "user"})
    stream = makeTestNativeStreamClient(context)

    url = stream.private.streamURL()
    prefix = stream.private.config.private.streamURI + "/meval/"

    a = m.assertEqual(left(url, prefix.len()), prefix)
    if a <> "" then
        return a
    end if

    encoded = mid(url, prefix.len() + 1)

    a = m.assertEqual(instr(1, encoded, "+"), 0)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(instr(1, encoded, "/"), 0)
    if a <> "" then
        return a
    end if

    decoded = createObject("roByteArray")
    decoded.fromBase64String(encoded.replace("-", "+").replace("_", "/"))

    return m.assertEqual(parseJSON(decoded.toAsciiString()).key, "???>>>")
end function

function TestCase__NativeStream_URLWithReasons() as String
    context = LaunchDarklyCreateContext({key: "user-key", kind: "user"})
    stream = makeTestNativeStreamClient(context)
    stream.private.config.setUseEvaluationReasons(true)

    url = stream.private.streamURL()

    return m.assertEqual(right(url, "?withReasons=true".len()), "?withReasons=true")
end function

function TestCase__NativeStream_ApplyPut() as String
    client = makeTestClientUninitialized()

    ok = LaunchDarklyApplyStreamEvent(client.private.config, client.private.store, client.status, "put", "{" + chr(34) + "flag1" + chr(34) + ":{" + chr(34) + "value" + chr(34) + ":true," + chr(34) + "version" + chr(34) + ":1}}")

    a = m.assertTrue(ok)
    if a <> "" then
        return a
    end if

    a = m.assertEqual(client.private.store.get("flag1").value, true)
    if a <> "" then
        return a
    end if

    return m.assertEqual(client.status.getStatus(), client.status.map.initialized)
end function

function TestCase__NativeStream_ApplyPatchAndDelete() as String
    client = makeTestClientUninitialized()
    config = client.private.config
    store = client.private.store

    LaunchDarklyApplyStreamEvent(config, store, client.status, "patch", FormatJSON({key: "flag1", value: "a", version: 2}))

    a = m.assertEqual(store.get("flag1").value, "a")
    if a <> "" then
        return a
    end if

    LaunchDarklyApplyStreamEvent(config, store, client.status, "delete", FormatJSON({key: "flag1", version: 3}))

    return m.assertEqual(store.get("flag1"), invalid)
end function

function TestCase__NativeStream_ApplyInvalidJSON() as String
    client = makeTestClientUninitialized()

    ok = LaunchDarklyApplyStreamEvent(client.private.config, client.private.store, client.status, "put", "{not json")

    return m.assertFalse(ok)
end function

function TestCase__NativeStream_ApplyIgnoresPing() as String
    client = makeTestClientUninitialized()
    config = client.private.config
    store = client.private.store

    LaunchDarklyApplyStreamEvent(config, store, client.status, "put", FormatJSON({flag1: {value: true, version: 1}}))

    ' Roku delivers a ping event with empty data.
    ok = LaunchDarklyApplyStreamEvent(config, store, client.status, "ping", "")

    a = m.assertTrue(ok)
    if a <> "" then
        return a
    end if

    return m.assertEqual(store.get("flag1").value, true)
end function

function TestCase__NativeStream_ApplyRejectsWrongShape() as String
    client = makeTestClientUninitialized()
    config = client.private.config
    store = LaunchDarklyStore()
    status = client.status

    cases = [
        {name: "put", data: "[1, 2]"},
        {name: "put", data: FormatJSON({flag1: "not an object"})},
        {name: "put", data: FormatJSON({flag1: {value: true}})},
        {name: "patch", data: "42"},
        {name: "patch", data: FormatJSON({key: "flag1", value: true})},
        {name: "patch", data: FormatJSON({key: 7, value: true, version: 1})},
        {name: "delete", data: FormatJSON({key: "flag1"})},
        {name: "delete", data: FormatJSON({version: 3})}
    ]

    for each c in cases
        a = m.assertFalse(LaunchDarklyApplyStreamEvent(config, store, status, c.name, c.data), c.name + " " + c.data)
        if a <> "" then
            return a
        end if
    end for

    return m.assertEqual(store.getAll().count(), 0)
end function

function TestCase__NativeStream_RecoverableStatus() as String
    for each code in [400, 408, 429, 500, 503, -28]
        a = m.assertTrue(LaunchDarklyIsRecoverableStreamStatus(code), code.toStr())
        if a <> "" then
            return a
        end if
    end for

    for each code in [401, 403, 404, 405]
        a = m.assertFalse(LaunchDarklyIsRecoverableStreamStatus(code), code.toStr())
        if a <> "" then
            return a
        end if
    end for

    return ""
end function

function TestCase__NativeStream_UnrecoverableErrorHalts() as String
    context = LaunchDarklyCreateContext({key: "user-key", kind: "user"})
    stream = makeTestNativeStreamClient(context)
    transfer = nativeStreamFakeTransfer()

    stream.private.transfer = transfer
    stream.private.handleTransferMessage(nativeStreamFakeUrlEvent(1, 404))

    a = m.assertTrue(transfer.cancelled)
    if a <> "" then
        return a
    end if

    a = m.assertTrue(stream.private.halted)
    if a <> "" then
        return a
    end if

    a = m.assertFalse(stream.private.canStream())
    if a <> "" then
        return a
    end if

    ' A new context opens the stream again.
    stream.changeContext(LaunchDarklyCreateContext({key: "other-key", kind: "user"}))

    return m.assertTrue(stream.private.canStream())
end function

function TestCase__NativeStream_UnauthorizedHalts() as String
    context = LaunchDarklyCreateContext({key: "user-key", kind: "user"})
    stream = makeTestNativeStreamClient(context)

    stream.private.transfer = nativeStreamFakeTransfer()
    stream.private.handleTransferMessage(nativeStreamFakeUrlEvent(1, 401))

    a = m.assertEqual(stream.private.status.getStatus(), stream.private.status.map.unauthorized)
    if a <> "" then
        return a
    end if

    return m.assertFalse(stream.private.canStream())
end function

function TestCase__NativeStream_RecoverableErrorRetries() as String
    context = LaunchDarklyCreateContext({key: "user-key", kind: "user"})
    stream = makeTestNativeStreamClient(context)

    for each code in [503, 429, -28, 200]
        transfer = nativeStreamFakeTransfer()
        stream.private.streamBackoff.reset()
        stream.private.transfer = transfer
        stream.private.handleTransferMessage(nativeStreamFakeUrlEvent(1, code))

        a = m.assertTrue(transfer.cancelled, code.toStr())
        if a <> "" then
            return a
        end if

        a = m.assertTrue(stream.private.canStream(), code.toStr())
        if a <> "" then
            return a
        end if

        a = m.assertTrue(stream.private.streamBackoff.shouldWait(), code.toStr())
        if a <> "" then
            return a
        end if
    end for

    return ""
end function

function TestCase__NativeStream_ConnectedEventKeepsStream() as String
    context = LaunchDarklyCreateContext({key: "user-key", kind: "user"})
    stream = makeTestNativeStreamClient(context)
    transfer = nativeStreamFakeTransfer()

    stream.private.transfer = transfer
    stream.private.handleTransferMessage(nativeStreamFakeUrlEvent(2, 200))

    return m.assertFalse(transfer.cancelled)
end function

function TestCase__NativeStream_NetworkReturnReconnects() as String
    context = LaunchDarklyCreateContext({key: "user-key", kind: "user"})
    stream = makeTestNativeStreamClient(context)
    transfer = nativeStreamFakeTransfer()
    backoff = stream.private.streamBackoff

    stream.private.transfer = transfer
    backoff.private.waitUntil = backoff.private.u.getMilliseconds() + 60000

    stream.private.handleNetworkMessage(nativeStreamFakeNetworkEvent({internetStatus: false}))

    a = m.assertFalse(transfer.cancelled, "network down must not close the stream")
    if a <> "" then
        return a
    end if

    stream.private.handleNetworkMessage(nativeStreamFakeNetworkEvent({internetStatus: true}))

    a = m.assertTrue(transfer.cancelled, "network up must replace the stream")
    if a <> "" then
        return a
    end if

    return m.assertFalse(backoff.shouldWait())
end function

function TestCase__NativeStream_NetworkUpWithoutDropKeepsStream() as String
    context = LaunchDarklyCreateContext({key: "user-key", kind: "user"})
    stream = makeTestNativeStreamClient(context)
    transfer = nativeStreamFakeTransfer()

    stream.private.linkUp = true
    stream.private.transfer = transfer
    stream.private.handleNetworkMessage(nativeStreamFakeNetworkEvent({linkStatus: true}))

    return m.assertFalse(transfer.cancelled)
end function

function TestSuite__NativeStream() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__NativeStream"

    this.addTest("TestCase__NativeStream_URLUsesURLSafeBase64", TestCase__NativeStream_URLUsesURLSafeBase64)
    this.addTest("TestCase__NativeStream_URLWithReasons", TestCase__NativeStream_URLWithReasons)
    this.addTest("TestCase__NativeStream_ApplyPut", TestCase__NativeStream_ApplyPut)
    this.addTest("TestCase__NativeStream_ApplyPatchAndDelete", TestCase__NativeStream_ApplyPatchAndDelete)
    this.addTest("TestCase__NativeStream_ApplyInvalidJSON", TestCase__NativeStream_ApplyInvalidJSON)
    this.addTest("TestCase__NativeStream_ApplyIgnoresPing", TestCase__NativeStream_ApplyIgnoresPing)
    this.addTest("TestCase__NativeStream_ApplyRejectsWrongShape", TestCase__NativeStream_ApplyRejectsWrongShape)
    this.addTest("TestCase__NativeStream_RecoverableStatus", TestCase__NativeStream_RecoverableStatus)
    this.addTest("TestCase__NativeStream_UnrecoverableErrorHalts", TestCase__NativeStream_UnrecoverableErrorHalts)
    this.addTest("TestCase__NativeStream_UnauthorizedHalts", TestCase__NativeStream_UnauthorizedHalts)
    this.addTest("TestCase__NativeStream_RecoverableErrorRetries", TestCase__NativeStream_RecoverableErrorRetries)
    this.addTest("TestCase__NativeStream_ConnectedEventKeepsStream", TestCase__NativeStream_ConnectedEventKeepsStream)
    this.addTest("TestCase__NativeStream_NetworkReturnReconnects", TestCase__NativeStream_NetworkReturnReconnects)
    this.addTest("TestCase__NativeStream_NetworkUpWithoutDropKeepsStream", TestCase__NativeStream_NetworkUpWithoutDropKeepsStream)

    return this
end function
