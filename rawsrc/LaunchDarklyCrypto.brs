function LaunchDarklyCryptoReader(launchDarklyParamCipherKey as Object, launchDarklyParamAuthKey as Object) as Object
    return {
        private: {
            stream: LaunchDarklyStream(),
            util: LaunchDarklyUtility(),

            REM cached read of the size of the current packet
            bodySize: invalid,
            REM defaults to zero, see getErrorString for details
            errorCode: 0,

            cipherKey: launchDarklyParamCipherKey.toHexString(),
            authKey: launchDarklyParamAuthKey,
            REM auth code of the previous packet
            lastMAC: invalid,

            REM size constants
            initVectorSize: 16,
            authCodeSize: 32,

            tryParseChunk: function() as Object
                REM read packet size
                if m.bodySize = invalid then
                    if m.stream.count() < 4 then
                        return invalid
                    end if

                    m.bodySize = m.util.littleEndianUnsignedToInteger(m.stream.takeCount(4))
                end if

                REM wait until full packet is available
                if m.stream.count() < m.initVectorSize + m.authCodeSize + m.bodySize then
                    return invalid
                end if

                REM split up packet
                launchDarklyLocalIv = m.stream.takeCount(m.initVectorSize).toHexString()
                launchDarklyLocalAuthCode = m.stream.takeCount(m.authCodeSize)
                launchDarklyLocalCipherText = m.stream.takeCount(m.bodySize)
                m.bodySize = invalid

                REM prepare authentication of packet
                launchDarklyLocalAuthContext = createObject("roHMAC")
                if launchDarklyLocalAuthContext.setup("sha256", m.authKey) <> 0 then
                    m.errorCode = 1
                    return invalid
                end if
                REM if not the first packet include the last packets auth code
                if m.lastMAC <> invalid then
                    launchDarklyLocalAuthContext.update(m.lastMAC)
                end if
                launchDarklyLocalAuthContext.update(launchDarklyLocalCipherText)

                REM generate mac from cipher text and maybe last mac
                launchDarklyLocalComputedAuthCode = launchDarklyLocalAuthContext.final()

                REM ensure the mac is as expected if not this may be an attack
                if m.util.byteArrayEq(launchDarklyLocalAuthCode, launchDarklyLocalComputedAuthCode) = false then
                    m.errorCode = 2
                    return invalid
                end if

                REM prepare decryption
                launchDarklyLocalCipherContext = createObject("roEVPCipher")
                if launchDarklyLocalCipherContext.setup(false, "aes-256-cbc", m.cipherKey, launchDarklyLocalIv, 1) <> 0 then
                    m.errorCode = 3
                    return invalid
                end if

                REM record this packets mac to be used in the next auth check
                m.lastMAC = launchDarklyLocalAuthCode

                REM ensure we cleanup now unused memory
                m.stream.shrink()

                REM finish with the actual decryption
                return launchDarklyLocalCipherContext.process(launchDarklyLocalCipherText)
            end function
        },

        getErrorString: function() as String
            launchDarklyLocalCode = m.private.errorCode

            if launchDarklyLocalCode = 1 then
                return "failed to create HMAC context"
            else if launchDarklyLocalCode = 2 then
                return "failed to verify HMAC"
            else if launchDarklyLocalCode = 3 then
                return "failed to create cipher context"
            end if

            return ""
        end function,

        getErrorCode: function() as Integer
            return m.private.errorCode
        end function,

        addBytes: function(launchDarklyParamBytes as Object) as Void
            m.private.stream.addBytes(launchdarklyParamBytes)
        end function,

        consumeEvent: function() as Object
            if m.private.errorCode = 0 then
                return m.private.tryParseChunk()
            else
                return invalid
            end if
        end function
    }
end function
