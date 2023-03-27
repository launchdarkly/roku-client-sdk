function TestCase__Context_FailsIfDataIsNotAssociativeArray() as String
  context = LaunchDarklyCreateContext(false)

  r =  m.assertFalse(context.isValid())
  if r <> "" then
    return r
  end if

  return m.assertEqual(context.error(), "context data is not an roAssociativeArray")
end function

' {{{ Legacy tests
function TestCase__Context_LegacyFormat_ValidatesTypes() as String
  testCases = [
    ' Validate name
    {"context": {"key": "my-key", "name": true}, "error": "context name must be a string"},
    {"context": {"key": "my-key", "name": 3}, "error": "context name must be a string"},
    {"context": {"key": "my-key", "name": ["my", "name"]}, "error": "context name must be a string"},

    ' Validate anonymous
    {"context": {"key": "my-key", "anonymous": "true"}, "error": "context anonymous must be a boolean"},
    {"context": {"key": "my-key", "anonymous": 3}, "error": "context anonymous must be a boolean"},
    {"context": {"key": "my-key", "anonymous": ["my", "anonymous"]}, "error": "context anonymous must be a boolean"},

    ' Validate custom
    {"context": {"key": "my-key", "custom": "true"}, "error": "context custom must be an roAssociativeArray"},
    {"context": {"key": "my-key", "custom": 3}, "error": "context custom must be an roAssociativeArray"},
    {"context": {"key": "my-key", "custom": true}, "error": "context custom must be an roAssociativeArray"},

    ' Validate private attributes
    {"context": {"key": "my-key", "privateAttributeNames": "true"}, "error": "context private attributes must be an array"},
    {"context": {"key": "my-key", "privateAttributeNames": 3}, "error": "context private attributes must be an array"},
    {"context": {"key": "my-key", "privateAttributeNames": true}, "error": "context private attributes must be an array"},
  ]

  for each testCase in testCases
    context = LaunchDarklyCreateContext(testCase["context"])

    r =  m.assertFalse(context.isValid())
    if r <> "" then
      return r
    end if

    r = m.assertEqual(testCase["error"], context.error())
    if r <> "" then
      return r
    end if
  end for

  return ""
end function

function TestCase__Context_LegacyFormat_CanCreate() as String
  context = LaunchDarklyCreateContext({"key": "my-key", "name": "Sandy", "custom": {"address": "123 Easy St."}})
  return m.assertTrue(context.isValid())
end function
' }}}

' {{{ Single-kind context tests
function TestCase__Context_SingleKind_ValidatesTypes() as String
  testCases = [
    ' Validate kind
    {"context": {"key": "my-key", "kind": "kind"}, "error": "'kind' is not a valid context kind"},
    {"context": {"key": "my-key", "kind": "invalid characters"}, "error": "context kind contains disallowed characters"},
    {"context": {"key": "my-key", "kind": ""}, "error": "context kind contains disallowed characters"},
    {"context": {"key": "my-key", "kind": 3}, "error": "context kind must be a string"},

    ' Validate key
    {"context": {"kind": "user", "key": 3}, "error": "context key must be a string"},
    {"context": {"kind": "user", "key": ""}, "error": "context key must not be empty"},

    ' Validate name
    {"context": {"kind": "user", "key": "my-key", "name": true}, "error": "context name must be a string"},
    {"context": {"kind": "user", "key": "my-key", "name": 3}, "error": "context name must be a string"},
    {"context": {"kind": "user", "key": "my-key", "name": ["my", "name"]}, "error": "context name must be a string"},

    ' Validate anonymous
    {"context": {"kind": "user", "key": "my-key", "anonymous": "true"}, "error": "context anonymous must be a boolean"},
    {"context": {"kind": "user", "key": "my-key", "anonymous": 3}, "error": "context anonymous must be a boolean"},
    {"context": {"kind": "user", "key": "my-key", "anonymous": ["my", "anonymous"]}, "error": "context anonymous must be a boolean"},

    ' Validate meta
    {"context": {"kind": "user", "key": "my-key", "_meta": "true"}, "error": "context _meta must be an roAssociativeArray"},
    {"context": {"kind": "user", "key": "my-key", "_meta": 3}, "error": "context _meta must be an roAssociativeArray"},
    {"context": {"kind": "user", "key": "my-key", "_meta": true}, "error": "context _meta must be an roAssociativeArray"},

    ' Validate private attributes
    {"context": {"kind": "user", "key": "my-key", "_meta": {"privateAttributes": "true"}}, "error": "context private attributes must be an array"},
    {"context": {"kind": "user", "key": "my-key", "_meta": {"privateAttributes": 3}}, "error": "context private attributes must be an array"},
    {"context": {"kind": "user", "key": "my-key", "_meta": {"privateAttributes": true}}, "error": "context private attributes must be an array"},
  ]

  for each testCase in testCases
    context = LaunchDarklyCreateContext(testCase["context"])

    r =  m.assertFalse(context.isValid())
    if r <> "" then
      return r
    end if

    r = m.assertEqual(testCase["error"], context.error())
    if r <> "" then
      return r
    end if
  end for

  return ""
end function

function TestCase__Context_SingleKind_CanCreate() as String
  context = LaunchDarklyCreateContext({"key": "my-key", "kind": "user", "name": "Sandy", "address": "123 Easy St."})
  return m.assertTrue(context.isValid())
end function
' }}}

' {{{ Multi-kind context tests
function TestCase__Context_MultiKind_ValidatesTypes() as String
  testCases = [
    ' Validate kind
    {"context": {"kind": "multi"}, "error": "multi-context must contain at least one kind"},
    {"context": {"kind": "multi", "user": {}}, "error": "context data must be an array of valid contexts"},
    {"context": {"kind": "multi", "user": {"key": ""}}, "error": "context data must be an array of valid contexts"},
  ]

  for each testCase in testCases
    context = LaunchDarklyCreateContext(testCase["context"])

    r =  m.assertFalse(context.isValid())
    if r <> "" then
      return r
    end if

    r = m.assertEqual(testCase["error"], context.error())
    if r <> "" then
      return r
    end if
  end for

  return ""
end function

function TestCase__Context_MultiKind_CanCreate() as String
  data = {
    "kind": "multi",
    "user": {"key": "user-key"},
    "org": {"key": "org-key"},
  }
  context = LaunchDarklyCreateContext(data)

  r = m.assertTrue(context.isValid())
  if r <> "" then
    return r
  end if

  return m.assertTrue(context.isMulti())
end function

function TestCase__Context_MultiKind_WithOneCreatesSingleKind() as String
  data = {
    "kind": "multi",
    "user": {"key": "user-key"},
  }
  context = LaunchDarklyCreateContext(data)

  r = m.assertTrue(context.isValid())
  if r <> "" then
    return r
  end if

  return m.assertFalse(context.isMulti())
end function
' }}}

function TestSuite__Context() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Context"

    this.addTest("TestCase__Context_FailsIfDataIsNotAssociativeArray", TestCase__Context_FailsIfDataIsNotAssociativeArray)

    this.addTest("TestCase__Context_LegacyFormat_ValidatesTypes", TestCase__Context_LegacyFormat_ValidatesTypes)
    this.addTest("TestCase__Context_LegacyFormat_CanCreate", TestCase__Context_LegacyFormat_CanCreate)

    this.addTest("TestCase__Context_SingleKind_ValidatesTypes", TestCase__Context_SingleKind_ValidatesTypes)
    this.addTest("TestCase__Context_SingleKind_CanCreate", TestCase__Context_SingleKind_CanCreate)

    this.addTest("TestCase__Context_MultiKind_ValidatesTypes", TestCase__Context_MultiKind_ValidatesTypes)
    this.addTest("TestCase__Context_MultiKind_CanCreate", TestCase__Context_MultiKind_CanCreate)
    this.addTest("TestCase__Context_MultiKind_WithOneCreatesSingleKind", TestCase__Context_MultiKind_WithOneCreatesSingleKind)

    return this
end function

' vim: foldmethod=marker foldlevel=0
