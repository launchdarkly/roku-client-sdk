function LaunchDarklyAttachContextPublicFunctions(context) as Object
  functions = {
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

    keys: function() as Object
      result = {}
      if m.isValid() = false then
        return result
      end if

      if m.isMulti() = false then
        result[m.private.kind] = m.private.key
      else
        for each context in m.private.contexts
          result[context.private.kind] = context.private.key
        end for
      end if

      return result
    end function,

    fullKey: function() as Object
      return m.private.fullyQualifiedKey
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
    end function,

    ' Returns the number of context kinds in this context.
    '
    ' For a valid individual context, this returns 1. For a multi-context, it
    ' returns the number of context kinds. For an invalid context, it returns
    ' zero.
    getIndividualContextCount: function() as Integer
      if m.isValid() = false then
        return 0
      end if

      if m.isMulti() then
        return m.private.contexts.Count()
      end if

      return 1
    end function,

    ' Returns the single-kind context corresponding to the index provided.
    '
    ' If this method is called on a single-kind LDContext, then the only
    ' allowable value for `index` is zero, and the return value on success
    ' is the same `m`.
    '
    ' If the method is called on a multi-context, `index` it must be a
    ' non-negative index that is less than the number of kinds (that is, less
    ' than the return value of `individual_context_count`, and the return value
    ' on success is one of the individual contexts within.
    '
    ' If there is no context corresponding to `kind`, the method returns nil.
    getIndividualContext: function(index as Integer) as Object
      if m.isMulti() then
        if index >= 0 and index < m.private.contexts.Count() then
          return m.private.contexts[index]
        end if

        return invalid
      end if

      if index = 0 then
        return m
      end if

      return invalid
    end function,

    ' Return an array of top level attribute keys (excluding built-in attributes)
    getCustomAttributeNames: function() as Object
      if m.private.attributes = invalid then
        return []
      end if

      return m.private.attributes.Keys()
    end function

    ' getValue looks up the value of any attribute of the context by name.
    ' This includes only attributes that are addressable in evaluations-- not
    ' metadata such as private attributes.
    '
    ' For a single-kind context, the attribute name can be any custom attribute.
    ' It can also be one of the built-in ones like "kind", "key", or "name".
    '
    ' For a multi-kind context, the only supported attribute name is "kind".
    '
    ' This method does not support complex expressions for getting individual
    ' values out of JSON objects or arrays, such as "/address/street". Use
    ' getValueForReference for that purpose.
    '
    ' If the value is found, the return value is the attribute value;
    ' otherwise, it is invalid.
    getValue: function(attribute) as Object
      reference = LaunchDarklyCreateReference(attribute, true)
      return m.getValueForReference(reference)
    end function

    ' getValueForReference looks up the value of any attribute of the
    ' context, or a value contained within an attribute, based on a reference
    ' instance. This includes only attributes that are addressable in
    ' evaluations-- not metadata such as private attributes.
    '
    ' This implements the same behavior that the SDK uses to resolve attribute
    ' references during a flag evaluation. In a single-kind context, the
    ' reference can represent a simple attribute name-- either a built-in one
    ' like "name" or "key", or a custom attribute -- or, it can be a
    ' slash-delimited path using a JSON-Pointer-like syntax. See LaunchDarklyCreateReference
    ' for more details.
    '
    ' For a multi-kind context, the only supported attribute name is "kind".
    '
    ' If the value is found, the return value is the attribute value;
    ' otherwise, it is invalid.
    getValueForReference: function(reference) as Object
      if m.isValid() = false then
        return invalid
      end if

      if reference.isValid() = false then
        return invalid
      end if

      firstComponent = reference.component(0)
      if firstComponent = invalid then
        return invalid
      end if

      if m.isMulti() then
        if reference.isKind() then
          return m.private.kind
        end if

        return invalid
      end if

      value = m.getTopLevelAddressableAttributeSingleKind(firstComponent)
      if value = invalid then
        return invalid
      end if

      for i = 1 to reference.depth() - 1
        name = reference.component(i)

        if type(value) <> "roAssociativeArray" then
          return invalid
        else if value.DoesExist(name) = false then
          return invalid
        end if

        value = value[name]
      end for

      return value
    end function,

    privateAttributes: function() as Object
      if m.private.privateAttributes = invalid then
        return []
      end if

      return m.private.privateAttributes
    end function,

    getTopLevelAddressableAttributeSingleKind: function(attributeName) as Object
      if attributeName = "kind" then
        return m.private.kind
      else if attributeName = "key"
        return m.private.key
      else if attributeName = "name"
        return m.private.name
      else if attributeName = "anonymous"
        return m.private.anonymous
      else
        return m.private.attributes?.lookup?(attributeName)
      end if
    end function
  }

  context.Append(functions)
  if context.private.contexts <> invalid then
    for each c in context.private.contexts
      LaunchDarklyAttachContextPublicFunctions(c)
    end for
  end if

  if context.private.privateAttributes <> invalid then
    for each p in context.private.privateAttributes
      LaunchDarklyAttachReferencePublicFunctions(p)
    end for
  end if
end function

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

    privateAttributeReferences = invalid
    if privateAttributes <> invalid then
      privateAttributeReferences = CreateObject("roArray", privateAttributes.Count(), false)

      for each privateAttribute in privateAttributes
        reference = LaunchDarklyCreateReference(privateAttribute)
        if reference.isValid() then
          privateAttributeReferences.Push(reference)
        end if
      end for
    end if


    context = {
      private: {
        ' The initial attribute here isn't a part of the context schema.
        ' Rather, it is used to ensure that the first context received by the
        ' LaunchDarklyTask doesn't trigger a call to the identify method.
        initial: false,
        key: key,
        fullyQualifiedKey: fullyQualifiedKey,
        kind: kind,
        name: name,
        anonymous: anonymous,
        attributes: attributes,
        privateAttributes: privateAttributeReferences,
        error: error,
        contexts: contexts,
        isMulti: contexts <> invalid
      }
    }

    LaunchDarklyAttachContextPublicFunctions(context)
    return context
  end function

  util = LaunchDarklyContextUtilities(createContext)

  if type(data) <> "roAssociativeArray" then
    return util.createInvalidContext("context data is not an roAssociativeArray")
  end if

  if data.DoesExist("kind") = false then
    return util.createLegacyContext(data)
  end if

  kind = data["kind"]
  if type(kind) <> "String" and type(kind) <> "roString" then
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
      kindRegex: CreateObject("roRegex", "[^a-zA-Z0-9._-]", ""),
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

      if type(key) <> "String" and type(key) <> "roString" then
        return m.createInvalidContext("context key must be a string")
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
      for each k in data
        if k = "ip" or k = "email" or k = "avatar" or k = "firstName" or k = "lastName" or k = "country" then
          value = data[k]
          if value = invalid then
            continue for
          end if

          if type(value) <> "String" and type(value) <> "roString" then
            return m.createInvalidContext("context " + k + " must be a string")
          end if

          if attributes = invalid then
            attributes = {}
          end if

          attributes[k] = value
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
      for each k in data
        if k <> "kind" and k <> "key" and k <> "name" and k <> "anonymous" and k <> "_meta" then
          if attributes = invalid then
            attributes = {}
          end if

          attributes[k] = data[k]
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
      if type(kind) <> "String" and type(kind) <> "roString" then
        return "context kind must be a string"
      end if

      if kind = "kind" then
        return "'kind' is not a valid context kind"
      else if kind = "multi" then
        return "'multi' is not a valid context kind"
      else if kind = "" then
        return "context kind must not be empty"
      end if

      if m.private.kindRegex.isMatch(kind) = false then
        return invalid
      end if

      return "context kind contains disallowed characters"
    end function,

    validateKey: function(key as Object) as Object
      if type(key) <> "String" and type(key) <> "roString" then
        return "context key must be a string"
      end if

      if key = "" then
        return "context key must not be empty"
      end if

      return invalid
    end function,

    validateName: function(name as Object) as Object
      if name = invalid or type(name) = "roString" or type(name) = "String" then
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

function NewLaunchDarklyContextFilter(config = invalid as Object) as Object
  if config <> invalid then
    return LaunchDarklyContextFilter(config.private.allAttributesPrivate, config.private.privateAttributeNames.Keys())
  else
    return LaunchDarklyContextFilter(false, [])
  end if
end function

function LaunchDarklyContextFilter(allAttributesPrivate as Boolean, privateAttributes as Object) as Object
  if type(privateAttributes) <> "roArray" then
    privateAttributes = []
  end if

  return {
    private: {
      allAttributesPrivate: allAttributesPrivate
      privateAttributes: privateAttributes,

      filterSingleContext: function(context as Object, includeKind as Boolean, includePrivateAttributes as Boolean, redactAnonymous as Boolean) as Object
        filtered = {key: context.key()}

        if includeKind then
          filtered["kind"] = context.kind()
        end if

        redactAll = m.allAttributesPrivate
        anonymous = context.getValue("anonymous")
        if anonymous = true then
          filtered["anonymous"] = true

          if redactAnonymous = true then
            redactAll = true
          end if
        end if

        privateAttributes = []
        if includePrivateAttributes = false then
          if type(m.privateAttributes) = "roArray" then
            for each attr in m.privateAttributes
              reference = LaunchDarklyCreateReference(attr)
              if reference.isValid() then
                privateAttributes.Push(reference)
              end if
            end for
          end if
          privateAttributes.Append(context.privateAttributes())
        end if

        redacted = []
        name = context.getValue("name")
        if name <> invalid and m.checkWholeAttributePrivate("name", privateAttributes, redacted, redactAll) = false
          filtered["name"] = name
        end if

        for each attribute in context.getCustomAttributeNames()
          if m.checkWholeAttributePrivate(attribute, privateAttributes, redacted, redactAll) = false
            value = context.getValue(attribute)
            redactedValue = m.redactJsonValue(invalid, attribute, value, privateAttributes, redacted)

            if redactedValue <> invalid then
              filtered[attribute] = redactedValue
            end if
          end if
        end for

        if includePrivateAttributes = false and redacted.Count() > 0 then
          filtered["_meta"] = {"redactedAttributes": redacted}
        else if includePrivateAttributes then
          attributes = []
          for each attr in context.privateAttributes()
            attributes.Push(attr.rawPath())
          end for
          filtered["_meta"] = {"privateAttributes": attributes}
        end if

        return filtered
      end function,

      checkWholeAttributePrivate: function(attribute as String, privateAttributes as Object, redacted as Object, redactAll as Boolean) as Object
        if redactAll then
          redacted.Push(attribute)
          return true
        end if

        for each privateAttribute in privateAttributes
          if privateAttribute.component(0) = attribute and privateAttribute.depth() = 1 then
            redacted.Push(attribute)
            return true
          end if
        end for

        return false
      end function,

      redactJsonValue: function(parentPath as Object, name as String, value as Object, privateAttributes as Object, redacted as Object) as Object
        if type(value) <> "roAssociativeArray" then
          return value
        end if

        ret = {}

        if parentPath = invalid then
          currentPath = []
        else
          currentPath = LaunchDarklyUtility().deepCopy(parentPath)
        end if

        currentPath.Push(name)

        for each k in value
          v = value[k]

          wasRedacted = false

          for each privateAttribute in privateAttributes
            if privateAttribute.depth() <> currentPath.Count() + 1 then
              continue for
            end if

            component = privateAttribute.component(currentPath.Count())
            if component <> k then
              continue for
            end if

            match = true
            for i = 0 to currentPath.Count() - 1
              if privateAttribute.component(i) <> currentPath[i]
                match = false
                exit for
              end if
            end for

            if match then
              redacted.Push(privateAttribute.rawPath())
              wasRedacted = true
            end if
          end for

          if wasRedacted = false then
            ret[k] = m.redactJsonValue(currentPath, k, v, privateAttributes, redacted)
          end if
        end for

        return ret
      end function
    },

    filter: function(context as Object, includePrivateAttributes = false As Boolean, redactAnonymous = false As Boolean) as Object
      if context.isMulti() = false then
        return m.private.filterSingleContext(context, true, includePrivateAttributes, redactAnonymous)
      end if

      filtered = {kind: "multi"}

      for i = 0 to context.getIndividualContextCount() - 1
        c = context.getIndividualContext(i)
        if c = invalid then
          continue for
        end if

        filtered[c.kind()] = m.private.filterSingleContext(c, false, includePrivateAttributes, redactAnonymous)
      end for

      return filtered
    end function
  }
end function
