function TestCase__Reference_Formats_Literal() as String
  testCases = [
    {literal: "name", path: "name"},
    {literal: "a/b", path: "a/b"},
    {literal: "/a/b~c", path: "/~1a~1b~0c"},
    {literal: "/", path: "/~1"},
  ]

  for each testCase in testCases
    literal = LaunchDarklyCreateReference(testCase["literal"], true)
    reference = LaunchDarklyCreateReference(testCase["path"], false)

    r = m.assertEqual(literal.rawPath(), reference.rawPath())
    if r <> "" then
      return r
    end if
  end for

  return ""
end function

function TestCase__Reference_Formats_Invalid() as String
  testCases = [
    ' Empty reference failures
    {reference: "", error: "empty reference"},
    {reference: "/", error: "empty reference"},

    ' Double or trailing slashes
    {reference: "//", error: "double or trailing slash"},
    {reference: "/a//b", error: "double or trailing slash"},
    {reference: "/a/b/", error: "double or trailing slash"},

    ' Invalid escape sequence
    {reference: "/a~x", error: "invalid escape sequence"},
    {reference: "/a~", error: "invalid escape sequence"},
    {reference: "/a/b~x", error: "invalid escape sequence"},
    {reference: "/a/b~", error: "invalid escape sequence"},
  ]

  for each testCase in testCases
    reference = LaunchDarklyCreateReference(testCase["reference"])

    r = m.assertEqual(testCase["error"], reference.error())
    if r <> "" then
      return r
    end if
  end for

  return ""
end function

function TestCase__Reference_Formats_Valid_WithoutLeadingSlashes() as String
  testCases = ["key", "kind", "name", "name/with/slashes", "name~0~1with-what-looks-like-escape-sequences"]

  for each testCase in testCases
    ref = LaunchDarklyCreateReference(testCase)

    r = m.assertEqual(testCase, ref.rawPath())
    if r <> "" then
      return r
    end if

    r = m.assertInvalid(ref.error())
    if r <> "" then
      return r
    end if

    r = m.assertEqual(1, ref.depth())
    if r <> "" then
      return r
    end if
  end for

  return ""
end function

function TestCase__Reference_Formats_Valid_WithLeadingSlashes() as String
  testCases = [
    {reference: "/key", component: "key"},
    {reference: "/0", component: "0"},
    {reference: "/name~1with~1slashes~0and~0tildes", component: "name/with/slashes~and~tildes"},
]

  for each testCase in testCases
    ref = LaunchDarklyCreateReference(testCase["reference"])

    r = m.assertEqual(testCase["reference"], ref.rawPath())
    if r <> "" then
      return r
    end if

    r = m.assertInvalid(ref.error())
    if r <> "" then
      return r
    end if

    r = m.assertEqual(1, ref.depth())
    if r <> "" then
      return r
    end if

    r = m.assertEqual(ref.component(0), testCase["component"])
    if r <> "" then
      return r
    end if
  end for

  return ""
end function

function TestCase__Reference_RetrieveComponents() as Object
  testCases = [
    {reference: "key", depth: 1, index: 0, component: "key"},
    {reference: "/key", depth: 1, index: 0, component: "key"},

    {reference: "/a/b", depth: 2, index: 0, component: "a"},
    {reference: "/a/b", depth: 2, index: 1, component: "b"},

    {reference: "/a~1b/c", depth: 2, index: 0, component: "a/b"},
    {reference: "/a~0b/c", depth: 2, index: 0, component: "a~b"},

    {reference: "/a/10/20/30x", depth: 4, index: 1, component: "10"},
    {reference: "/a/10/20/30x", depth: 4, index: 2, component: "20"},
    {reference: "/a/10/20/30x", depth: 4, index: 3, component: "30x"},

    ' invalid arguments don't cause an error, they just return invalid
    {reference: "", depth: 0, index: 0, component: invalid},
    {reference: "", depth: 0, index: -1, component: invalid},

    {reference: "key", depth: 1, index: -1, component: invalid},
    {reference: "key", depth: 1, index: 1, component: invalid},

    {reference: "/key", depth: 1, index: -1, component: invalid},
    {reference: "/key", depth: 1, index: 1, component: invalid},

    {reference: "/a/b", depth: 2, index: -1, component: invalid},
    {reference: "/a/b", depth: 2, index: 2, component: invalid},
  ]

  for each testCase in testCases
    ref = LaunchDarklyCreateReference(testCase["reference"])

    r = m.assertEqual(ref.depth(), testCase["depth"])
    if r <> "" then
      return r
    end if

    r = m.assertEqual(ref.component(testCase["index"]), testCase["component"])
    if r <> "" then
      return r
    end if
  end for

  return ""
end function

function TestSuite__Reference() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Reference"

    this.addTest("TestCase__Reference_Formats_Literal", TestCase__Reference_Formats_Literal)
    this.addTest("TestCase__Reference_Formats_Invalid", TestCase__Reference_Formats_Invalid)
    this.addTest("TestCase__Reference_Formats_Valid_WithoutLeadingSlashes", TestCase__Reference_Formats_Valid_WithoutLeadingSlashes)
    this.addTest("TestCase__Reference_Formats_Valid_WithLeadingSlashes", TestCase__Reference_Formats_Valid_WithLeadingSlashes)

    this.addTest("TestCase__Reference_RetrieveComponents", TestCase__Reference_RetrieveComponents)

    return this
end function
