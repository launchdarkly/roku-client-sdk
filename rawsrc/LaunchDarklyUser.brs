function LaunchDarklyUser(launcDarklyParamUserKey as String) as Object
    return {
        private: {
            key: launchDarklyParamUserKey,
            anonymous: false,
            firstName: invalid,
            lastName: invalid,
            email: invalid,
            name: invalid,
            avatar: invalid,
            custom: invalid,
            privateAttributeNames: {}
        },

        setAnonymous: function(launchDarklyParamAnonymous as Boolean) as Void
            m.private.anonymous = launchDarklyParamAnonymous
        end function,

        setFirstName: function(launchDarklyParamFirstName as String) as Void
            m.private.firstName = launchDarklyParamFirstName
        end function,

        setLastName: function(launchDarklyParamLastName as String) as Void
            m.private.lastName = launchDarklyParamLastName
        end function,

        setEmail: function(launchDarklyParamEmail as String) as Void
            m.private.email = launchDarklyParamEmail
        end function,

        setName: function(launchDarklyParamName as String) as Void
            m.private.name = launchDarklyParamName
        end function,

        setAvatar: function(launchDarklyParamAvatar as String) as Void
            m.private.avatar = launchdarklyParamAvatar
        end function,

        setCustom: function(launchDarklyParamCustom as Object) as Void
            m.private.custom = launchdarklyParamCustom
        end function,

        addPrivateAttribute: function(launchDarklyParamPrivateAttribute as String) as Void
            m.private.privateAttributeNames.addReplace(launchDarklyParamPrivateAttribute, 1)
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
