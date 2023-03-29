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

function TestCase__Context_LegacyFormat_CanRetrieveBasicAttributes() as String
  context = LaunchDarklyCreateContext({"key": "my-key", "name": "Sandy", "anonymous": true})

  testCases = [
    {reference: "kind", expected: "user"},
    {reference: "key", expected: "my-key"},
    {reference: "name", expected: "Sandy"},
    {reference: "anonymous", expected: true},
    {reference: "privateAttributeNames", expected: invalid},
    {reference: "privateAttributes", expected: invalid}
  ]

  for each testCase in testCases
    reference = LaunchDarklyCreateReference(testCase["reference"])
    r = m.assertEqual(testCase["expected"], context.getValueForReference(reference))
    if r <> "" then
      return r
    end if
  end for

  return ""
end function

function TestCase__Context_LegacyFormat_CanRetrieveComplexAttributes() as String
  address = { city: "Oakland", state: "CA", zip: 94612 }
  tags = ["LaunchDarkly", "Feature Flags"]
  nested = { upper: { middle: { name: "Middle Level", inner: { levels: [0, 1, 2] } }, name: "Upper Level" } }

  context = LaunchDarklyCreateContext({ key: "user", name: "Ruby", custom: { address: address, tags: tags, nested: nested }})

  testCases = [
    ' Simple top level attributes are accessible
    {reference: "/address", expected: address},
    {reference: "/address/city", expected: "Oakland"},

    {reference: "/tags", expected: tags},

    {reference: "/nested/upper/name", expected: "Upper Level"},
    {reference: "/nested/upper/middle/name", expected: "Middle Level"},
    {reference: "/nested/upper/middle/inner/levels", expected: [0, 1, 2]},
  ]

  for each testCase in testCases
    reference = LaunchDarklyCreateReference(testCase["reference"])
    r = m.assertEqual(testCase["expected"], context.getValueForReference(reference))
    if r <> "" then
      return r
    end if
  end for

  return ""
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

function TestCase__Context_SingleKind_CanRetrieveBasicAttributes() as String
  context = LaunchDarklyCreateContext({"key": "my-key", "kind": "org", "name": "LaunchDarkly", "anonymous": false})

  testCases = [
    {reference: "kind", expected: "org"},
    {reference: "key", expected: "my-key"},
    {reference: "name", expected: "LaunchDarkly"},
    {reference: "anonymous", expected: false},
    {reference: "privateAttributeNames", expected: invalid},
    {reference: "privateAttributes", expected: invalid}
  ]

  for each testCase in testCases
    reference = LaunchDarklyCreateReference(testCase["reference"])
    r = m.assertEqual(testCase["expected"], context.getValueForReference(reference))
    if r <> "" then
      return r
    end if
  end for

  return ""
end function

function TestCase__Context_SingleKind_CanRetrieveComplexAttributes() as String
  address = { city: "Oakland", state: "CA", zip: 94612 }
  tags = ["LaunchDarkly", "Feature Flags"]
  nested = { upper: { middle: { name: "Middle Level", inner: { levels: [0, 1, 2] } }, name: "Upper Level" } }

  context = LaunchDarklyCreateContext({ key: "ld", kind: "org", name: "LaunchDarkly", anonymous: true, address: address, tags: tags, nested: nested })

  testCases = [
    ' Simple top level attributes are accessible
    {reference: "/address", expected: address},
    {reference: "/address/city", expected: "Oakland"},

    {reference: "/tags", expected: tags},

    {reference: "/nested/upper/name", expected: "Upper Level"},
    {reference: "/nested/upper/middle/name", expected: "Middle Level"},
    {reference: "/nested/upper/middle/inner/levels", expected: [0, 1, 2]},
  ]

  for each testCase in testCases
    reference = LaunchDarklyCreateReference(testCase["reference"])
    r = m.assertEqual(testCase["expected"], context.getValueForReference(reference))
    if r <> "" then
      return r
    end if
  end for

  return ""
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

function TestCase__Context_MultiKind_CanOnlyRetrieveKindValue() as String
  data = {
    "kind": "multi",
    "user": {"key": "user-key"},
    "org": {"key": "org-key"},
  }
  context = LaunchDarklyCreateContext(data)

  testCases = [
    {reference: "kind", result: "multi"},
    {reference: "key", result: invalid},
    {reference: "name", result: invalid},
    {reference: "anonymous", result: invalid},
  ]

  for each testCase in testCases
    reference = LaunchDarklyCreateReference(testCase["reference"])
    result = context.getValueForReference(reference)

    r = m.assertEqual(testCase["result"], result)
    if r <> "" then
      return r
    end if
  end for

  return ""
end function
' }}}

function TestSuite__Context() as Object
    this = BaseTestSuite()

    this.name = "TestSuite__Context"

    this.addTest("TestCase__Context_FailsIfDataIsNotAssociativeArray", TestCase__Context_FailsIfDataIsNotAssociativeArray)

    this.addTest("TestCase__Context_LegacyFormat_ValidatesTypes", TestCase__Context_LegacyFormat_ValidatesTypes)
    this.addTest("TestCase__Context_LegacyFormat_CanCreate", TestCase__Context_LegacyFormat_CanCreate)
    this.addTest("TestCase__Context_LegacyFormat_CanRetrieveBasicAttributes", TestCase__Context_LegacyFormat_CanRetrieveBasicAttributes)
    this.addTest("TestCase__Context_LegacyFormat_CanRetrieveComplexAttributes", TestCase__Context_LegacyFormat_CanRetrieveComplexAttributes)

    this.addTest("TestCase__Context_SingleKind_ValidatesTypes", TestCase__Context_SingleKind_ValidatesTypes)
    this.addTest("TestCase__Context_SingleKind_CanCreate", TestCase__Context_SingleKind_CanCreate)
    this.addTest("TestCase__Context_SingleKind_CanRetrieveBasicAttributes", TestCase__Context_SingleKind_CanRetrieveBasicAttributes)
    this.addTest("TestCase__Context_SingleKind_CanRetrieveComplexAttributes", TestCase__Context_SingleKind_CanRetrieveComplexAttributes)

    this.addTest("TestCase__Context_MultiKind_ValidatesTypes", TestCase__Context_MultiKind_ValidatesTypes)
    this.addTest("TestCase__Context_MultiKind_CanCreate", TestCase__Context_MultiKind_CanCreate)
    this.addTest("TestCase__Context_MultiKind_WithOneCreatesSingleKind", TestCase__Context_MultiKind_WithOneCreatesSingleKind)
    this.addTest("TestCase__Context_MultiKind_CanOnlyRetrieveKindValue", TestCase__Context_MultiKind_CanOnlyRetrieveKindValue)

    return this
end function

' vim: foldmethod=marker foldlevel=0
