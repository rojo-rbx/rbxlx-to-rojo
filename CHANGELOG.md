# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2021-04-11
### Fixed
- Fixed newer builds not being usable.

## [1.0.0] - 2021-01-06
### Added
- Added support for .rbxl and .rbxm, and not just .rbxlx.

### Changed
- Changed file reading mechanism to be one that should be more optimized, increasing read times. You can further increase read times by switching to binary (.rbxl, .rbxm) files instead of using .rbxlx.
