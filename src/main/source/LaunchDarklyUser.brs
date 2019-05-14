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

            isAttributePublic: function(attribute as String, config as Object) as Boolean
                if config <> invalid then
                    if config.private.allAttributesPrivate = true then
                        return false
                    end if

                    if config.private.privateAttributeNames.lookup(attribute) <> invalid then
                        return false
                    end if
                end if

                if m.privateAttributeNames.lookup(attribute) <> invalid then
                    return false
                end if

                return true
            end function,

            addField: function(result, context, field, config, privateAttrs) as Void
                value = context.lookup(field)
                if value <> invalid then
                    if privateAttrs <> invalid then
                        if m.isAttributePublic(field, config) = true then
                            result.addReplace(field, value)
                        else
                            privateAttrs.push(field)
                        end if
                    else
                        result.addReplace(field, value)
                    end if
                end if
            end function,

            encode: function(redact as Boolean, config=invalid as Object) as Object
                encoded = {
                    key: m.key
                }

                privateAttrs = invalid

                if redact = true then
                    privateAttrs = createObject("roArray", 0, true)
                end if

                if m.anonymous = true then
                    encoded.anonymous = true
                end if

                m.addField(encoded, m, "firstName", config, privateAttrs)
                m.addField(encoded, m, "lastName", config, privateAttrs)
                m.addField(encoded, m, "email", config, privateAttrs)
                m.addField(encoded, m, "name", config, privateAttrs)
                m.addField(encoded, m, "avatar", config, privateAttrs)

                if m.custom <> invalid then
                    custom = {}

                    for each attribute in m.custom
                        m.addField(custom, m.custom, attribute, config, privateAttrs)
                    end for

                    encoded.custom = custom
                end if

                if redact = true AND privateAttrs.count() <> 0 then
                    encoded.privateAttrs = privateAttrs
                end if

                return encoded
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
        addPrivateAttribute: function(privateAttribute as String) as Void
            m.private.privateAttributeNames.addReplace(privateAttribute, 1)
        end function
    }
end function
