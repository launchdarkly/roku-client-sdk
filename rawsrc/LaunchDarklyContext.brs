' Create an evaluation context from the provided associative array.
'
' A context is a collection of attributes that can be referenced in flag
' evaluations and analytics events. This function accepts an associative array
' of data that must match the expected LaunchDarkly context schema, or the
' legacy user schema. To learn more, read
' https://docs.launchdarkly.com/home/contexts.
'
' This function will always return an Object representing a context. However,
' that context may be invalid. You can check the validity of the resulting
' context, and the associated errors by calling `context.isValid()` and
' `context.error()`.
function LaunchDarklyCreateContext(data as Object) as Object
  createContext = function (key, fullyQualifiedKey, kind, name = invalid, anonymous = invalid, attributes = invalid, privateAttributes = invalid, error = invalid, contexts = invalid) as Object
    if anonymous = invalid then
      anonymous = false
    end if

    return {
      private: {
        key: key,
        fullyQualifiedKey: fullyQualifiedKey,
        kind: kind,
        name: name,
        anonymous: anonymous,
        attributes: attributes,
        privateAttributes: privateAttributes,
        error: error,
        contexts: contexts,
        isMulti: contexts <> invalid
      },

      ' @return A string if an error exists; invalid otherwise.
      error: function() as Object
        if m.private.error = invalid then
          return ""
        end if

        return m.private.error
      end function,

      ' @return A string representing the key for single-kind contexts; invalid otherwise.
      key: function() as Object
        return m.private.key
      end function,

      ' @return A string representing the kind for valid contexts; invalid otherwise.
      kind: function() as Object
        return m.private.kind
      end function,

      ' @return Boolean determining whether or not the context is valid
      isValid: function() as Boolean
        if m.private.error = invalid then
          return true
        end if

        return false
      end function,

      ' @return Boolean determining whether or not the context is a multi-kind context
      isMulti: function() as Boolean
        return m.private.isMulti
      end function
    }
  end function

  util = LaunchDarklyContextUtilities(createContext)

  if type(data) <> "roAssociativeArray" then
    return util.createInvalidContext("context data is not an roAssociativeArray")
  end if

  kind = data["kind"]
  if kind = invalid then
    return util.createLegacyContext(data)
  end if

  if type(kind) <> "roString" then
    return util.createInvalidContext("context kind must be a string")
  end if

  if kind = "multi" then
    contexts = CreateObject("roArray", data.Count(), false)
    for each key in data
      if key <> "kind" then
        contexts.Push(util.createSingleKindContext(data[key], key))
      end if
    end for

    return util.createMultiKindContext(contexts)
  end if

  return util.createSingleKindContext(data, kind)
end function

' An internally used object with utility functions for validating and
' constructing the different types of contexts.
'
' @internal
' @param createContext A function responsible for constructing a context
' @return An object representing our utility functions
function LaunchDarklyContextUtilities(createContext as Function) as Object
  return {
    private: {
      createContext: createContext
      kindRegex: CreateObject("roRegex", "^[a-zA-Z0-9._-]+$", ""),
    },

    ' Convenience method for constructing invalid contexts with the provided
    ' error message.
    '
    ' @param error Error explaining why the context is considered invalid
    ' @return a context object
    createInvalidContext: function(error as String) as Object
      return m.private.createContext(invalid, invalid, invalid, invalid, false, invalid, invalid, error)
    end function,

    ' Attempt to create a context using the legacy user format.
    '
    ' @param data Associative array containing the user data
    ' @return a context object
    createLegacyContext: function(data as Object) as Object
      if type(data) <> "roAssociativeArray" then
        return m.createInvalidContext("context data is not an roAssociativeArray")
      end if

      key = data["key"]
      if key = invalid then
        return m.createInvalidContext("context key must not be null or empty")
      end if

      name = data["name"]
      nameError = m.validateName(name)
      if nameError <> invalid then
        return m.createInvalidContext(nameError)
      end if

      anonymous = data["anonymous"]
      anonymousError = m.validateAnonymous(anonymous, true)
      if anonymousError <> invalid then
        return m.createInvalidContext(anonymousError)
      end if

      custom = data["custom"]
      if custom <> invalid and type(custom) <> "roAssociativeArray" then
        return m.createInvalidContext("context custom must be an roAssociativeArray")
      end if

      attributes = custom
      for each key in data
        if key = "ip" or key = "email" or key = "avatar" or key = "firstName" or key = "lastName" or key = "country" then
          if attributes = invalid then
            attributes = {}
          end if

          attributes[key] = data[key]
        end if
      end for

      privateAttributes = data["privateAttributeNames"]
      if privateAttributes <> invalid and type(privateAttributes) <> "roArray" then
        return m.createInvalidContext("context private attributes must be an array")
      end if

      return m.private.createContext(key, key, "user", name, anonymous, attributes, privateAttributes)
    end function,

    ' Attempt to create a single-kind context using the new context format.
    '
    ' @param data Associative array containing the context data
    ' @return a context object
    createSingleKindContext: function(data as Object, kind as Object) as Object
      if type(data) <> "roAssociativeArray" then
        return m.createInvalidContext("context data is not an roAssociativeArray")
      end if

      kindError = m.validateKind(kind)
      if kindError <> invalid then
        return m.createInvalidContext(kindError)
      end if

      key = data["key"]
      keyError = m.validateKey(key)
      if keyError <> invalid then
        return m.createInvalidContext(keyError)
      end if

      name = data["name"]
      nameError = m.validateName(name)
      if nameError <> invalid then
        return m.createInvalidContext(nameError)
      end if

      anonymous = data["anonymous"]
      if anonymous = invalid then
        anonymous = false
      end if
      anonymousError = m.validateAnonymous(anonymous, false)
      if anonymousError <> invalid then
        return m.createInvalidContext(anonymousError)
      end if

      meta = data["_meta"]
      if meta = invalid then
        meta = {}
      end if

      if type(meta) <> "roAssociativeArray" then
        return m.createInvalidContext("context _meta must be an roAssociativeArray")
      end if

      privateAttributes = meta["privateAttributes"]
      if privateAttributes <> invalid and type(privateAttributes) <> "roArray" then
        return m.createInvalidContext("context private attributes must be an array")
      end if

      ' We only need to create an attribute hash if there are keys set outside
      ' of the ones we store in dedicated instance variables.
      attributes = invalid
      for each key in data
        if key <> "kind" and key <> "key" and key <> "name" and key <> "anonymous" and key <> "_meta" then
          if attributes = invalid then
            attributes = {}
          end if

          attributes[key] = data[key]
        end if
      end for

      fullKey = key
      if kind <> "user" then
        fullKey = m.canonicalizeKeyForKind(kind, key)
      end if

      return m.private.createContext(key, fullKey, kind, name, anonymous, attributes, privateAttributes)
    end function,

    ' Attempt to create a multi-kind context from the provided single-kind contexts.
    '
    ' If only a single, valid context is provided, this method will return that
    ' context instead of constructing a single-instance multi-kind context.
    '
    ' If any of the provided contexts are invalid, or if they duplicate any of
    ' the same kinds, this function will return an invalid context.
    '
    ' @param contexts An array of valid context objects
    ' @return a context object
    createMultiKindContext: function(contexts as Object) as Object
      if type(contexts) <> "roArray" then
        return m.createInvalidContext("context data must be an array of valid contexts")
      end if

      if contexts.Count() = 0 then
        return m.createInvalidContext("multi-context must contain at least one kind")
      end if

      kinds = {}
      for each context in contexts
        if context.isValid() = false then
          return m.createInvalidContext("context data must be an array of valid contexts")
        else if context.isMulti() = true then
          return m.createInvalidContext("multi-kind context cannot contain another multi-kind context")
        else if kinds.DoesExist(context.kind()) then
          return m.createInvalidContext("multi-kind context cannot have same kind more than once")
        end if

        kinds[context.kind()] = context.key()
      end for

      if contexts.Count() = 1 then
        return contexts[0]
      end if

      fullKeys = CreateObject("roArray", kinds.Count(), false)

      kindKeys = kinds.Keys()
      kindKeys.Sort()
      for each kind in kindKeys
        fullKeys.Push(m.canonicalizeKeyForKind(kind, kinds[kind]))
      end for

      return m.private.createContext(invalid, fullKeys.Join(":"), "multi", invalid, false, invalid, invalid, invalid, contexts)

    end function,

    validateKind: function(kind as Object) as Object
      if type(kind) <> "roString" then
        return "context kind must be a string"
      end if

      if kind = "kind" then
        return "'kind' is not a valid context kind"
      else if kind = "multi" then
        return "'multi' is not a valid context kind"
      end if

      if m.private.kindRegex.isMatch(kind) then
        return invalid
      end if

      return "context kind contains disallowed characters"
    end function,

    validateKey: function(key as Object) as Object
      if type(key) <> "roString" then
        return "context key must be a string"
      end if

      if key = "" then
        return "context key must not be empty"
      end if

      return invalid
    end function,

    validateName: function(name as Object) as Object
      if name = invalid or type(name) = "roString" then
        return invalid
      end if

      return "context name must be a string"
    end function,

    validateAnonymous: function(anonymous as Object, allowInvalid as Boolean) as Object
      if anonymous = invalid and allowInvalid then
        return invalid
      end if

      if type(anonymous) = "roBoolean" then
        return invalid
      end if

      return "context anonymous must be a boolean"
    end function,

    canonicalizeKeyForKind: function(kind as String, key as String) as String
      ' When building a fully qualified key, ':' and '%' are percent-escaped;
      ' we do not use a full URL-encoding function because implementations of
      ' this are inconsistent across platforms.
      encoded = key.Replace("%", "%25").Replace(":", "%3A")

      return kind + ":" + encoded
    end function
  }
end function
