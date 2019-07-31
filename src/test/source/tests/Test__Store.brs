function makeFlag(key as String, version as Integer) as Object
    return {
        key: key,
        version: version
    }
end function

function TestCase__Store_UpsertGet() as String
    store = m.testinstance.store

    a = m.assertEqual(invalid, store.get("a"))
    if a <> "" then
        return a
    end if

    store.upsert(makeFlag("a", 1))

    a = m.assertEqual(1, store.get("a").version)
    if a <> "" then
        return a
    end if

    store.upsert(makeFlag("a", 2))

    a = m.assertEqual(2, store.get("a").version)
    if a <> "" then
        return a
    end if

    store.upsert(makeFlag("a", 1))

    return m.assertEqual(2, store.get("a").version)
end function

function TestCase__Store_Delete() as String
    store = m.testinstance.store

    store.delete("a", 1)
    store.upsert(makeFlag("a", 2))

    a = m.assertEqual(2, store.get("a").version)
    if a <> "" then
        return a
    end if

    store.delete("a", 1)

    a = m.assertEqual(2, store.get("a").version)
    if a <> "" then
        return a
    end if

    store.delete("a", 7)

    return m.assertEqual(invalid, store.get("a"))
end function

function TestCase__Store_PutAllGetAll() as String
    store = m.testinstance.store

    store.putAll({
        "a": makeFlag("a", 3),
        "b": makeFlag("b", 5),
        "c": makeFlag("c", 2)
    })

    store.delete("b", 6)

    return m.assertEqual(store.getAll(), {
        "a": makeFlag("a", 3),
        "c": makeFlag("c", 2)
    })
end function

function MetaTestSuite__Store(s) as Object
    this = BaseTestSuite()

    this.addTest("TestCase__Store_UpsertGet", TestCase__Store_UpsertGet, s)
    this.addTest("TestCase__Store_Delete", TestCase__Store_Delete, s)
    this.addTest("TestCase__Store_PutAllGetAll", TestCase__Store_PutAllGetAll, s)

    return this
end function

function TestSuite__Store_Memory() as Object
    setup = function() as Void
        m.store = LaunchDarklyStore()
    end function

    this = MetaTestSuite__Store(setup)

    this.name = "TestSuite__Store_Memory"

    return this
end function

function TestSuite__Store_Registry() as Object
    setup = function() as Void
        namespace = "LaunchDarklyTest"
        createObject("roRegistry").delete(namespace)
        m.store = LaunchDarklyStore(LaunchDarklyStoreRegistry(namespace))
    end function

    this = MetaTestSuite__Store(setup)

    this.name = "TestSuite__Store_Registry"

    return this
end function

function TestSuite__Store_Registry_Bypass() as Object
    setup = function() as Void
        namespace = "LaunchDarklyTest"
        createObject("roRegistry").delete(namespace)
        m.store = LaunchDarklyStore(LaunchDarklyStoreRegistry(namespace))
        m.store.private.bypassReadCache = true
    end function

    this = MetaTestSuite__Store(setup)

    this.name = "TestSuite__Store_Registry_Bypass"

    return this
end function
