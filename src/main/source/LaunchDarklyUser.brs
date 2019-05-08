function LaunchDarklyUser(userKey as String) as Object
    return {
        private: {
            key: userKey,
            encode: function() as String
                return FormatJSON({
                    key: m.key
                })
            end function
        }
    }
end function
