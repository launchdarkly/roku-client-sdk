function TestCase__SSE_MultipleLines() as String
    p = LaunchDarklySSE()

    p.addChunk("data: AB" + chr(10) + "data: CD" + chr(10))
    p.addChunk("data: EF" + chr(10) + chr(10))

    a = m.assertEqual(p.consumeEvent(), {
        name: "",
        value: "AB" + chr(10) + "CD" + chr(10) + "EF"
    })
    if a <> "" then
        return a
    end if

    return m.assertEqual(p.consumeEvent(), invalid)
end function

function TestCase__SSE_MultipleEvents() as String
    p = LaunchDarklySSE()

    p.addChunk("event: PUT" + chr(10) + "data: 1" + chr(10) + chr(10))
    p.addChunk("event: PATCH" + chr(10) + "data: 2" + chr(10) + chr(10))

    return m.assertEqual(p.consumeEvent(), {
        name: "PUT",
        value: "1"
    })
    if a <> "" then
        return a
    end if

    return m.assertEqual(p.consumeEvent(), {
        name: "PATCH",
        value: "2"
    })
    if a <> "" then
        return a
    end if

    return m.assertEqual(p.consumeEvent(), invalid)
end function

function TestCase__SSE_OptionalSpace() as String
    p = LaunchDarklySSE()

    p.addChunk("data:500" + chr(10) + chr(10))

    a = m.assertEqual(p.consumeEvent(), {
        name: "",
        value: "500"
    })
    if a <> "" then
        return a
    end if

    return m.assertEqual(p.consumeEvent(), invalid)
end function

function TestCase__SSE_NoPartial() as String
    p = LaunchDarklySSE()

    p.addChunk("data:52" + chr(10))

    return m.assertEqual(p.consumeEvent(), invalid)
end function

function TestCase__SSE_SkipComment() as String
    p = LaunchDarklySSE()

    p.addChunk(": my comment" + chr(10) + chr(10))

    return m.assertEqual(p.consumeEvent(), invalid)
end function

function TestCase__SSE_AcrossChunks() as String
    p = LaunchDarklySSE()

    p.addChunk("dat")
    p.addChunk("a: AB")
    p.addChunk("C" + chr(10) + chr(10))

    a = m.assertEqual(p.consumeEvent(), {
        name: "",
        value: "ABC"
    })
    if a <> "" then
        return a
    end if

    return m.assertEqual(p.consumeEvent(), invalid)
end function

function TestSuite__SSE() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__SSE"

    this.addTest("TestCase__SSE_MultipleLines", TestCase__SSE_MultipleLines)
    this.addTest("TestCase__SSE_MultipleEvents", TestCase__SSE_MultipleEvents)
    this.addTest("TestCase__SSE_OptionalSpace", TestCase__SSE_OptionalSpace)
    this.addTest("TestCase__SSE_NoPartial", TestCase__SSE_NoPartial)
    this.addTest("TestCase__SSE_SkipComment", TestCase__SSE_SkipComment)
    this.addTest("TestCase__SSE_AcrossChunks", TestCase__SSE_AcrossChunks)

    return this
end function
