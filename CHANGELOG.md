# Change log

All notable changes to the LaunchDarkly Roku SDK will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org).

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
