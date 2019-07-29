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
            privateAttributeNames: {}
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

function LaunchDarklyUserEncode(user as Object, redact as Boolean, config=invalid as Object)
    u = user.private

    addField = function(user, result, context, field, config, privateAttrs) as Void
        value = context.lookup(field)
        if value <> invalid then
            if privateAttrs <> invalid then
                isAttributePublic = function(user, context as Object, attribute as String, config as Object) as Boolean
                    if config <> invalid then
                        if config.private.allAttributesPrivate = true then
                            return false
                        end if

                        if config.private.privateAttributeNames.lookup(attribute) <> invalid then
                            return false
                        end if
                    end if

                    if user.privateAttributeNames.lookup(attribute) <> invalid then
                        return false
                    end if

                    return true
                end function

                if isAttributePublic(user, context, field, config) = true then
                    result.addReplace(field, value)
                else
                    privateAttrs.push(field)
                end if
            else
                result.addReplace(field, value)
            end if
        end if
    end function

    encoded = {
        key: u.key
    }

    privateAttrs = invalid

    if redact = true then
        privateAttrs = createObject("roArray", 0, true)
    end if

    if m.anonymous = true then
        encoded.anonymous = true
    end if

    addField(u, encoded, u, "firstName", config, privateAttrs)
    addField(u, encoded, u, "lastName", config, privateAttrs)
    addField(u, encoded, u, "email", config, privateAttrs)
    addField(u, encoded, u, "name", config, privateAttrs)
    addField(u, encoded, u, "avatar", config, privateAttrs)

    if u.custom <> invalid then
        custom = {}

        for each attribute in u.custom
            addField(u, custom, u.custom, attribute, config, privateAttrs)
        end for

        encoded.custom = custom
    end if

    if redact = true AND privateAttrs.count() <> 0 then
        encoded.privateAttrs = privateAttrs
    end if

    return encoded
end function
