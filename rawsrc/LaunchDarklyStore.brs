function LaunchDarklyStoreSG(launchDarklyParamNode) as Object
    return {
        private: {
            node: launchDarklyParamNode
        },

        initialized: function() as Boolean
          ' WARN: If the environment has 0 flags, this store will report that
          ' it is not initialized even though it technically is.
          '
          ' Ideally we would have a way to distinguish between those two states
          ' but doing so requires extending the surface interface of the
          ' SceneGraph by adding another field or changing the format of the
          ' existing data.
          '
          ' Long term it would be good to change the payloads in the flags node
          ' to store the initialization status along with the flag values
          ' instead of treating them separately.
          return m.private.node.flags.Count() > 0
        end function,

        get: function(launchDarklyParamKey as String) as Object
            return m.private.node.flags.lookup(launchDarklyParamKey)
        end function,

        getAll: function() as Object
            return m.private.node.flags
        end function,

        put: function(launchDarklyParamFlag as Object) as Void
            launchDarklyLocalFlags = m.private.node.flags
            launchDarklyLocalFlags[launchDarklyParamFlag.key] = launchDarklyParamFlag
            m.private.node.flags = launchDarklyLocalFlags
        end function,

        putAll: function(launchDarklyParamNextFlags as Object) as Void
            m.private.node.flags = launchDarklyParamNextFlags
        end function
    }
end function

function LaunchDarklyStoreRegistry(launchDarklyParamSectionName as String) as Object
    return {
        private: {
            section: createObject("roRegistrySection", launchDarklyParamSectionName)
        },

        get: function(launchDarklyParamKey as String) as Object
            launchDarklyLocalSerialized = m.private.section.read(launchDarklyParamKey)

            if launchDarklyLocalSerialized <> "" then
                return parseJSON(launchDarklyLocalSerialized)
            end if

            return invalid
        end function,

        getAll: function() as Object
            launchDarklyLocalResult = {}

            for each launchDarklyLocalFlagKey in m.private.section.getKeyList()
                launchDarklyLocalResult[launchDarklyLocalFlagKey] = m.get(launchDarklyLocalFlagKey)
            end for

            return launchDarklyLocalResult
        end function,

        put: function(launchDarklyParamFlag as Object) as Void
            m.private.section.write(launchDarklyParamFlag.key, formatJSON(launchDarklyParamFlag))
        end function,

        putAll: function(launchDarklyParamNextFlags as Object) as Void
            for each launchDarklyLocalFlagKey in m.private.section.getKeyList()
                m.private.section.delete(launchDarklyLocalFlagKey)
            end for

            for each launchDarklyLocalFlagKey in launchDarklyParamNextFlags
                m.put(launchDarklyParamNextFlags[launchDarklyLocalFlagKey])
            end for
        end function
    }
end function

function LaunchDarklyStore(launchDarklyParamBackend=invalid as Object) as Object
    launchDarklyLocalThis = {
        private: {
            cache: {},
            backend: launchDarklyParamBackend,
            bypassReadCache: false,
            initialized: false
        },

        initialized: function() as Boolean
          return m.private.initialized
        end function,

        get: function(launchDarklyParamKey as String) as Object
            launchDarklyLocalFlag = invalid

            if m.private.bypassReadCache = true then
                launchDarklyLocalFlag = m.private.backend.get(launchDarklyParamKey)
            else
                launchDarklyLocalFlag = m.private.cache.lookup(launchDarklyParamKey)
            end if

            if launchDarklyLocalFlag = invalid OR launchDarklyLocalFlag.deleted = true then
                return invalid
            else
                return launchDarklyLocalFlag
            end if
        end function,

        getAll: function() as Object
            launchDarklyLocalResult = {}
            launchDarklyLocalItems = invalid

            if m.private.bypassReadCache = true then
                launchDarklyLocalItems = m.private.backend.getAll()
            else
                launchDarklyLocalItems = m.private.cache
            end if

            for each launchDarklyLocalFlagKey in launchDarklyLocalItems
                launchDarklyLocalFlag = launchDarklyLocalItems.lookup(launchDarklyLocalFlagKey)

                if launchDarklyLocalFlag.deleted <> true then
                    launchDarklyLocalResult[launchDarklyLocalFlagKey] = launchDarklyLocalFLag
                end if
            end for

            return launchDarklyLocalResult
        end function,

        upsert: function(launchDarklyParamReplacementFlag as Object) as Void
            launchDarklyLocalExisting = invalid

            if m.private.bypassReadCache = true then
                launchDarklyLocalExisting = m.private.backend.get(launchDarklyParamReplacementFlag.key)
            else
                launchDarklyLocalExisting = m.private.cache.lookup(launchDarklyParamReplacementFlag.key)
            end if

            if launchDarklyLocalExisting = invalid OR launchDarklyParamReplacementFlag.version > launchDarklyLocalExisting.version then
                m.private.cache[launchDarklyParamReplacementFlag.key] = launchDarklyParamReplacementFlag

                if m.private.backend <> invalid then
                    m.private.backend.put(launchDarklyParamReplacementFlag)
                end if
            end if
        end function,

        putAll: function(launchDarklyParamFlags as Object) as Void
            m.private.cache = launchDarklyParamFlags
            m.private.initialized = true

            if m.private.backend <> invalid then
                m.private.backend.putAll(launchDarklyParamFlags)
            end if
        end function,

        delete: function(launchDarklyParamFlagKey as String, launchDarklyParamFlagVersion as Integer) as Void
            m.upsert({
                key: launchDarklyParamFlagKey,
                version: launchDarklyParamFlagVersion,
                deleted: true
            })
        end function
    }

    if launchDarklyParamBackend <> invalid then
        launchDarklyLocalThis.private.cache = launchDarklyParamBackend.getAll()
    end if

    return launchDarklyLocalThis
end function
