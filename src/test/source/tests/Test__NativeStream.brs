function makeTestNativeStreamClient(context as Object) as Object
    client = makeTestClientUninitialized()
    return LaunchDarklyNativeStreamClient(client.private.config, client.private.store, CreateObject("roMessagePort"), context, client.status)
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

function TestSuite__NativeStream() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__NativeStream"

    this.addTest("TestCase__NativeStream_URLUsesURLSafeBase64", TestCase__NativeStream_URLUsesURLSafeBase64)
    this.addTest("TestCase__NativeStream_URLWithReasons", TestCase__NativeStream_URLWithReasons)
    this.addTest("TestCase__NativeStream_ApplyPut", TestCase__NativeStream_ApplyPut)
    this.addTest("TestCase__NativeStream_ApplyPatchAndDelete", TestCase__NativeStream_ApplyPatchAndDelete)
    this.addTest("TestCase__NativeStream_ApplyInvalidJSON", TestCase__NativeStream_ApplyInvalidJSON)

    return this
end function
