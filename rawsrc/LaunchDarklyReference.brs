function LaunchDarklyAttachReferencePublicFunctions(reference) as Object
    functions = {
      rawPath: function() as String
        return m.private.rawPath
      end function,

      error: function() as Object
        return m.private.error
      end function,

      isValid: function() as Boolean
        if m.private.error = invalid then
          return true
        end if

        return false
      end function,

      ' Convenience method to quickly check if the reference refers to a
      ' context's kind.
      isKind: function() as Boolean
        if m.depth() <> 1 then
          return false
        end if

        return m.component(0) = "kind"
      end function,

      ' Retrieves a single path component from the attribute reference.
      '
      ' For a simple attribute reference such as "name" with no leading slash, if
      ' index is zero, component returns the attribute name as a string.
      '
      ' For an attribute reference with a leading slash, if index is non-negative
      ' and less than depth, component returns the path component as a string.
      '
      ' If index is out of range, it returns invalid.
      '
      ' Reference.create("a").component(0)    # returns "a"
      ' Reference.create("/a/b").component(1) # returns "b"
      component: function(index as Integer) as Object
        if index < 0 or index > m.depth() then
          return invalid
        end if

        return m.private.components[index]
      end function,

      ' Returns the number of path components in the Reference.
      '
      ' For a simple attribute reference such as "name" with no leading slash,
      ' this returns 1.
      '
      ' For an attribute reference with a leading slash, it is the number of
      ' slash-delimited path components after the initial slash. For instance,
      ' LaunchDarklyCreateReference("/a/b").depth() returns 2.
      depth: function() as Integer
        return m.private.components.Count()
      end function
    }

    reference.Append(functions)
end function

' Reference is an attribute name or path expression identifying a value
' within a context.
'
' It can be used to retrieve a value with context.getValueForReference()
' or to identify an attribute or nested value that should be considered
' private.
'
' Parsing and validation are done at the time that the Reference is
' constructed. If a reference instance was created from an invalid string, it
' is considered invalid and calling reference.error() will return a string
' containing the error condition.
'
' ## Syntax
'
' The string representation of an attribute reference in LaunchDarkly JSON
' data uses the following syntax:
'
' If the first character is not a slash, the string is interpreted literally
' as an attribute name. An attribute name can contain any characters, but
' must not be empty.
'
' If the first character is a slash, the string is interpreted as a
' slash-delimited path where the first path component is an attribute name,
' and each subsequent path component is the name of a property in a JSON
' object. Any instances of the characters "/" or "~" in a path component are
' escaped as "~1" or "~0" respectively. This syntax deliberately resembles
' JSON Pointer, but no JSON Pointer behaviors other than those mentioned here
' are supported.
'
' ## Examples
'
' Suppose there is a context whose JSON implementation looks like this:
'
' {
'   "kind": "user",
'   "key": "value1",
'   "address": {
'     "street": {
'       "line1": "value2",
'       "line2": "value3"
'     },
'     "city": "value4"
'   },
'   "good/bad": "value5"
' }
'
' The attribute references "key" and "/key" would both point to "value1".
'
' The attribute reference "/address/street/line1" would point to "value2".
'
' The attribute references "good/bad" and "/good~1bad" would both point to
' "value5".
'
function LaunchDarklyCreateReference(value as String, asLiteral = false as Boolean) as Object
  createReference = function(rawPath as Object, components as Object, error = invalid) as Object
    reference = {
      private: {
        rawPath: rawPath,
        components: components,
        error: error,
      },
    }

    LaunchDarklyAttachReferencePublicFunctions(reference)
    return reference
  end function

  util = LaunchDarklyReferenceUtilities(createReference)

  if asLiteral = true then
    return util.createReferenceLiteral(value)
  end if

  return util.createReference(value)
end function

function LaunchDarklyReferenceUtilities(createReference as Function) as Object
  return {
    private: {
      createReference: createReference,
      unescapePath: function(path) as Object
        if path.InStr("~") = -1 then
          return {
            path: path,
            error: invalid
          }
        end if

        pathSize = path.Len()

        output = box("")
        i = 0
        while i < pathSize
          if path.Mid(i, 1) <> "~" then
            output.AppendString(path.Mid(i, 1), 1)
            i++
            continue while
          end if

          if i + 1 = pathSize then
            return {
              path: invalid,
              error: "invalid escape sequence"
            }
          end if

          nextChar = path.Mid(i + 1, 1)
          if nextChar = "0" then
            output.AppendString("~", 1)
          else if nextChar = "1" then
            output.AppendString("/", 1)
          else
            return {
              path: invalid,
              error: "invalid escape sequence"
            }
          end if

          i += 2
        end while

        return {
          path: output,
          error: invalid
        }
      end function
    },

    ' This constructor always returns a Reference that preserves the original
    ' string, even if validation fails, so that accessing {#raw_path} (or
    ' serializing the Reference to JSON) will produce the original string. If
    ' validation fails, {#error} will return a non-nil error and any SDK method
    ' that takes this Reference as a parameter will consider it invalid.
    createReference: function(value as String) as Object
      if value = "/" or value = "" then
        return m.private.createReference(value, [], "empty reference")
      end if

      if value.StartsWith("/") = false then
        return m.private.createReference(value, [value])
      end if

      if value.EndsWith("/") = true then
        return m.private.createReference(value, [], "double or trailing slash")
      end if

      parts = value.Right(value.Len() - 1).Split("/")
      components = CreateObject("roArray", parts.Count(), true)

      for each part in parts
        if part = "" then
          return m.private.createReference(value, [], "double or trailing slash")
        end if

        unescaped = m.private.unescapePath(part)

        if unescaped.error <> invalid then
          return m.private.createReference(value, [], unescaped.error)
        end if

        components.Push(unescaped.path)
      end for

      return m.private.createReference(value, components)
    end function,

    ' createReferenceLiteral is similar to createReference except that it always
    ' interprets the string as a literal attribute name, never as a
    ' slash-delimited path expression. There is no escaping or unescaping, even
    ' if the name contains literal '/' or '~' characters. Since an attribute
    ' name can contain any characters, this method always returns a valid
    ' Reference unless the name is empty.
    '
    ' For example: createReferenceLiteral("name") is exactly equivalent to
    ' createReference("name"). Reference.createReferenceLiteral("a/b") is exactly
    ' equivalent to createReference("a/b") (since the syntax used by createReference
    ' treats the whole string as a literal as long as it does not start with a
    ' slash), or to createReference("/a~1b").
    createReferenceLiteral: function(value as String) as Object
      if value = "" then
        return m.private.createReference(value, [], "empty reference")
      end if

      if value.StartsWith("/") = false then
        return m.private.createReference(value, [value])
      end if

      escaped = "/" + value.Replace("~", "~0").Replace("/", "~1")
      return m.private.createReference(escaped, [value])
    end function
  }
end function
