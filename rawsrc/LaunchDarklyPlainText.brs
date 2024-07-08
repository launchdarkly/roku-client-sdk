function LaunchDarklyPlainTextReader() as Object
    return {
        private: {
            stream: LaunchDarklyStream(),

            tryParseChunk: function() as Object
                if m.stream.count() = 0 then
                  return invalid
                end if

                plaintext = m.stream.takeCount(m.stream.count())
                m.stream.shrink()

                return plaintext
            end function
        },

        getErrorString: function() as String
            return ""
        end function,

        getErrorCode: function() as Integer
          return 0
        end function,

        addBytes: function(launchDarklyParamBytes as Object) as Void
            m.private.stream.addBytes(launchdarklyParamBytes)
        end function,

        consumeEvent: function() as Object
          return m.private.tryParseChunk()
        end function
    }
end function
