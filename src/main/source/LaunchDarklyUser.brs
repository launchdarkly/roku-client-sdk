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
            privateAttributeNames: CreateObject("roList"),
            encode: function() as String
                return FormatJSON({
                    key: m.key
                })
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
        setCustom: function(custom as Object) as Void
            m.private.custom = custom
        end function,
        setPrivateAttributes: function(privateAttributes as Object) as Void
            m.privateAttributeNames = privateAttributes
        end function,
        addPrivateAttribute: function(privateAttribute as String) as Void
            m.privateAttributeNames.addTail(privateAttribute)
        end function
    }
end function
