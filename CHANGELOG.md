# Change log

All notable changes to the LaunchDarkly Roku SDK will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org).

## [2.0.0] - 2023-04-13
The latest version of this SDK supports LaunchDarkly's new custom contexts feature. Contexts are an evolution of a previously-existing concept, "users." Contexts let you create targeting rules for feature flags based on a variety of different information, including attributes pertaining to users, organizations, devices, and more. You can even combine contexts to create "multi-contexts." 

For detailed information about this version, please refer to the list below. For information on how to upgrade from the previous version, please read the [migration guide](https://docs.launchdarkly.com/sdk/client-side/roku/migration-1-to-2).

### Added:
- A new context type can be created by providing an associative array to the `LaunchDarklyCreateContext` function.
- A new reference type can be created by providing a string path to the `LaunchDarklyCreateReference` function.
- For all SDK methods that took a user parameter, you can now pass the new context type instead.

### Removed:
- Removed the `LaunchDarklyUser` function and all supporting user related functionality.
- The `alias` method no longer exists because alias events are not needed in the new context model.
- The `setInlineUsers` and `setAutoAliasingOptOut` configuration functions no longer exists because they are not relevant in the new context model.

## [1.3.0] - 2023-04-11
### Added:
- New config method `setApplicationInfoValue` allows setting application metadata that may be used in LaunchDarkly analytics or other product features. This does not affect feature flag evaluations.
- Added support for country as a top level property on the user object.
- Added support for inline user configuration option.
- Introduced a simplified version of the allFlagsState method.

### Fixed:
- Event payload ID was not changing between successful payloads as expected.
- Updated event payloads to match expected schema.

## [1.2.0] - 2021-07-23
### Added:
- Added the `Alias` method. This can be used to associate two user objects for analytics purposes with an alias event.

### Fixed:
- `DoubleVariation` is now guaranteed to return a `Double` value rather than an integer or `Float` type, regardless of whether the value could be represented as an integer.

## [1.1.5] - 2020-05-19
### Changed:
- Refactored internal event processing logic

## [1.1.4] - 2020-05-13
### Fixed:
- Corrected summary event schema to no longer include user info

## [1.1.3] - 2020-04-10
### Fixed:
- Standardized streaming retry behavior. First delay is always 1 second, delay is capped at 30 seconds, and if the stream is productive for 60 seconds reset back-off.

## [1.1.2] - 2020-01-27
### Fixed:
- The SDK will no longer send empty event payloads to LaunchDarkly.

## [1.1.1] - 2020-01-17
### Fixed
- The SDK now specifies a uniquely identifiable request header when sending events to LaunchDarkly to ensure that events are only processed once, even if the SDK sends them two times due to a failed initial attempt.
- The SDK will now retry event delivery on failure.

## [1.1.0] - 2019-11-12
### Added
- A `LaunchDarklySDKVersion` function that returns the SDK version

## [1.0.1] - 2019-11-08
### Fixed
- Dereference of an `invalid` value in streaming mode

## [1.0.0] - 2019-11-04
First GA release. No associated changes.

## [1.0.0-rc.3] - 2019-10-24
### Added
- Added support for the new LaunchDarkly experimentation functionality. An optional numeric metric parameter has been added the `track` method.
- The new family of `*VariationDetail` methods allows you to evaluate a feature flag (using the same parameters as you would for `*Variation`) and receive more information about how the value was calculated. This information is returned in an object that contains both the result value and a "reason" object which will tell you, for instance, if the user was individually targeted for the flag or was matched by one of the flag's rules, or if the flag returned the default value due to an error.

## [1.0.0-rc.2] - 2019-10-08
### Fixed
- Schema validation bug in streaming

## [1.0.0-rc.1] - 2019-09-17
### Changed
- Renamed `aaVariation` to `jsonVariation`. Now supports arrays.
### Fixed
- Identify event not generated on initialization in core client
- Scenegraph API generates extra identify event on initialization
- Polling not starting instantly when identify is called
- Increased streaming HMAC coverage increasing security

## [1.0.0-beta.2] - 2019-08-26
### Added
- Client status API
- User IP address field
### Fixed
- Internally prefixed all variables to reduce namespace conflicts
- Type coercion for numbers during flag evaluation
- Identify event schema
- Feature event schema
- User schema
- Handling of streaming delete events
- Identify ignored with scenegraph API
- Track ignored with scenegraph API
- Flush ignored with scenegraph API
