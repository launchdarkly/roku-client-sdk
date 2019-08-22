function LaunchDarklyUser(launchDarklyParamUserKey as String) as Object
    return {
        private: {
            key: launchDarklyParamUserKey,
            anonymous: false,
            firstName: invalid,
            lastName: invalid,
            email: invalid,
            name: invalid,
            avatar: invalid,
            ip: invalid,
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
            m.private.avatar = launchDarklyParamAvatar
        end function,

        setCustom: function(launchDarklyParamCustom as Object) as Void
            m.private.custom = launchDarklyParamCustom
        end function,

        setIP: function(launchDarklyParamIP as String) as Void
            m.private.ip = launchDarklyParamIP
        end function,

        addPrivateAttribute: function(launchDarklyParamPrivateAttribute as String) as Void
            m.private.privateAttributeNames.addReplace(launchDarklyParamPrivateAttribute, 1)
        end function
    }
end function

function LaunchDarklyUserEncode(launchDarklyParamUser as Object, launchDarklyParamRedact as Boolean, launchDarklyParamConfig=invalid as Object)
    launchDarklyLocalAddField = function(launchDarklyParamUser, launchDarklyParamResult, launchDarklyParamContext, launchDarklyParamField, launchDarklyParamConfig, launchDarklyParamPrivateAttrs) as Void
        launchDarklyLocalValue = launchDarklyParamContext.lookup(launchDarklyParamField)

        if launchDarklyLocalValue <> invalid then
            if launchDarklyParamPrivateAttrs <> invalid then
                launchDarklyLocalIsAttributePublic = function(launchDarklyParamUser as Object, launchDarklyParamContext as Object, launchDarklyParamAttribute as String, launchDarklyParamConfig as Object) as Boolean
                    if launchDarklyParamConfig <> invalid then
                        if launchDarklyParamConfig.private.allAttributesPrivate = true then
                            return false
                        end if

                        if launchDarklyParamConfig.private.privateAttributeNames.lookup(launchDarklyParamAttribute) <> invalid then
                            return false
                        end if
                    end if

                    if launchDarklyParamUser.privateAttributeNames.lookup(launchDarklyParamAttribute) <> invalid then
                        return false
                    end if

                    return true
                end function

                if launchDarklyLocalIsAttributePublic(launchDarklyParamUser, launchDarklyParamContext, launchDarklyParamField, launchDarklyParamConfig) = true then
                    launchDarklyParamResult.addReplace(launchdarklyParamField, launchDarklyLocalValue)
                else
                    launchDarklyParamPrivateAttrs.push(launchDarklyParamField)
                end if
            else
                launchDarklyParamResult.addReplace(launchDarklyParamField, launchDarklyLocalValue)
            end if
        end if
    end function

    launchDarklyLocalEncoded = {
        key: launchDarklyParamUser.private.key
    }

    launchDarklyLocalPrivateAttrs = invalid

    if launchDarklyParamRedact = true then
        launchDarklyLocalPrivateAttrs = createObject("roArray", 0, true)
    end if

    if launchDarklyParamUser.private.anonymous = true then
        launchDarklyLocalEncoded.anonymous = true
    end if

    launchDarklyLocalAddField(launchDarklyParamUser.private, launchDarklyLocalEncoded, launchDarklyParamUser.private, "firstName", launchDarklyParamConfig, launchDarklyLocalPrivateAttrs)
    launchDarklyLocalAddField(launchDarklyParamUser.private, launchDarklyLocalEncoded, launchDarklyParamUser.private, "lastName", launchDarklyParamConfig, launchDarklyLocalPrivateAttrs)
    launchDarklyLocalAddField(launchDarklyParamUser.private, launchDarklyLocalEncoded, launchDarklyParamUser.private, "email", launchDarklyParamConfig, launchDarklyLocalPrivateAttrs)
    launchDarklyLocalAddField(launchDarklyParamUser.private, launchDarklyLocalEncoded, launchDarklyParamUser.private, "name", launchDarklyParamConfig, launchDarklyLocalPrivateAttrs)
    launchDarklyLocalAddField(launchDarklyParamUser.private, launchDarklyLocalEncoded, launchDarklyParamUser.private, "avatar", launchDarklyParamConfig, launchDarklyLocalPrivateAttrs)
    launchDarklyLocalAddField(launchDarklyParamUser.private, launchDarklyLocalEncoded, launchDarklyParamUser.private, "ip", launchDarklyParamConfig, launchDarklyLocalPrivateAttrs)

    if launchDarklyParamUser.private.custom <> invalid then
        launchDarklyLocalCustom = {}

        for each launchDarklyLocalAttribute in launchDarklyParamUser.private.custom
            launchDarklyLocalAddField(launchDarklyParamUser.private, launchDarklyLocalCustom, launchDarklyParamUser.private.custom, launchDarklyLocalAttribute, launchDarklyParamConfig, launchDarklyLocalPrivateAttrs)
        end for

        launchDarklyLocalEncoded.custom = launchDarklyLocalCustom
    end if

    if launchDarklyParamRedact = true AND launchDarklyLocalPrivateAttrs.count() <> 0 then
        launchDarklyLocalEncoded["privateAttrs"] = launchDarklyLocalPrivateAttrs
    end if

    return launchDarklyLocalEncoded
end function
