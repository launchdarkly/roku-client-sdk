function LaunchDarklyUser(userKey as String) as Object
    return {
        private: {
            key: userKey,
            anonymous: false,
            firstName: invalid,
            lastName: invalid,
            email: invalid,
            name: invalid,
            avatar: invalid,
            custom: invalid,
            privateAttributeNames: {},
            encode: function() as String
                redacted = {
                    key: m.key
                }

                if m.anonymous = true then
                    redacted.anonymous = true
                end if

                if m.firstName <> invalid then
                    redacted.firstName = m.firstName
                end if

                if m.lastName <> invalid then
                    redacted.lastName = m.lastName
                end if

                if m.email <> invalid then
                    redacted.email = m.email
                end if

                if m.avatar <> invalid then
                    redacted.avatar = m.avatar
                end if

                if m.custom <> invalid then
                    custom = {}
                    privateAttrs = createObject("roArray")

                    for each attribute in m.custom
                        if m.privateAttributeNames.lookup(attribute) = invalid then
                            custom.addReplace(attribute, m.custom.lookup(attribute))
                        else
                            privateAttrs.push(attribute)
                        end if
                    end for

                    redacted.custom = custom
                    redacted.privateAttrs = privateAttrs
                end if

                return FormatJSON(redacted)
            end function
        },
        setAnonymous: function(anonymous as Boolean) as Void
            m.private.anonymous = anonymous
        end function,
        setFirstName: function(firstName as String) as Void
            m.private.firstName = firstName
        end function,
        setLastName: function(lastName as String) as Void
            m.private.lastName = lastName
        end function,
        setEmail: function(email as String) as Void
            m.private.email = email
        end function,
        setName: function(name as String) as Void
            m.private.name = name
        end function,
        setAvatar: function(avatar as String) as Void
            m.private.avatar = avatar
        end function,
        addPrivateAttribute: function(privateAttribute as String) as Void
            m.privateAttributeNames.addReplace(privateAttribute, 1)
        end function
    }
end function
