function LaunchDarklyStoreSG(node) as Object
    return {
        private: {
            node: node
        },

        get: function(key as String) as Object
            return m.private.node.flags.lookup(key)
        end function,

        getAll: function() as Object
            return m.private.node.flags
        end function,

        put: function(flag as Object) as Void
            flags = m.private.node.flags
            flags[flag.key] = flag
            m.private.node.flags = flags
        end function,

        putAll: function(nextFlags as Object) as Void
            m.private.node.flags = nextFlags
        end function
    }
end function

function LaunchDarklyStoreRegistry(sectionName as String) as Object
    return {
        private: {
            section: createObject("roRegistrySection", sectionName)
        },

        get: function(key as String) as Object
            serialized = m.private.section.read(key)

            if serialized <> "" then
                return parseJSON(serialized)
            end if

            return invalid
        end function,

        getAll: function() as Object
            result = {}

            for each flagKey in m.private.section.getKeyList()
                result[flagKey] = m.get(flagKey)
            end for

            return result
        end function,

        put: function(flag as Object) as Void
            m.private.section.write(flag.key, formatJSON(flag))
        end function,

        putAll: function(nextFlags as Object) as Void
            for each flagKey in m.private.section.getKeyList()
                m.private.section.delete(flagKey)
            end for

            for each flagKey in nextFlags
                m.put(nextFlags[flagKey])
            end for
        end function
    }
end function

function LaunchDarklyStore(backend=invalid as Object) as Object
    this = {
        private: {
            cache: {},
            backend: backend,
            bypassReadCache: false
        },

        get: function(key as String) as Object
            flag = invalid

            if m.private.bypassReadCache = true then
                flag = m.private.backend.get(key)
            else
                flag = m.private.cache.lookup(key)
            end if

            if flag = invalid OR flag.deleted = true then
                return invalid
            else
                return flag
            end if
        end function,

        getAll: function() as Object
            result = {}
            items = invalid

            if m.private.bypassReadCache = true then
                items = m.private.backend.getAll()
            else
                items = m.private.cache
            end if

            for each flagKey in items
                flag = items.lookup(flagKey)

                if flag.deleted <> true then
                    result[flagKey] = flag
                end if
            end for

            return result
        end function,

        upsert: function(replacementFlag as Object) as Void
            existing = invalid

            if m.private.bypassReadCache = true then
                existing = m.private.backend.get(replacementFlag.key)
            else
                existing = m.private.cache.lookup(replacementFlag.key)
            end if

            if existing = invalid OR replacementFlag.version > existing.version then
                m.private.cache[replacementFlag.key] = replacementFlag

                if m.private.backend <> invalid then
                    m.private.backend.put(replacementFlag)
                end if
            end if
        end function,

        putAll: function(flags as Object) as Void
            m.private.cache = flags

            if m.private.backend <> invalid then
                m.private.backend.putAll(flags)
            end if
        end function,

        delete: function(flagKey as String, flagVersion as Integer) as Void
            m.upsert({
                key: flagKey,
                version: flagVersion,
                deleted: true
            })
        end function
    }

    if backend <> invalid then
        this.private.cache = backend.getAll()
    end if

    return this
end function
