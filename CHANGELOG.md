# Change log

All notable changes to the LaunchDarkly Roku SDK will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org).

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
