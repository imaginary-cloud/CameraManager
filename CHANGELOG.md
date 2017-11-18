# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [4.0.1](https://github.com/imaginary-cloud/CameraManager/tree/4.0.1) - 2017-11-18

### Added

- Add @discardableResult modifiers to addPreviewLayerToView (pull request #132)

### Fixed 

- Fix shouldEnableTapToFocus function (pull request #133)

## [4.0.0](https://github.com/imaginary-cloud/CameraManager/tree/4.0.0) - 2017-10-22
### Changed

- Syntax update for Swift 4.0 (pull request #125)

### Fixed

- Add gesture recognizers on the main thread (pull request #123)

## [3.2.0](https://github.com/imaginary-cloud/CameraManager/tree/3.2.0) - 2017-07-03
### Added

- Add location data to videos (pull request #110)
- Optional location permissions (pull request #110)

## [3.1.4](https://github.com/imaginary-cloud/CameraManager/tree/3.1.4) - 2017-06-14
### Added

- Add properties `focusMode` and `exposureMode` (pull request #106)
- Add property `animateShutter` to disable shutter animation

### Fixed

- FlashMode on front camera (issue #82)
- Zoom of front camera not working (issue #84)
- Getting same video URL, when simultaneously recording video (issue #108)

## [3.1.3](https://github.com/imaginary-cloud/CameraManager/tree/3.1.3) - 2017-05-15
### Added

- Add two new properties `shouldEnableTapToFocus` and `shouldEnablePinchToZoom` (pull request #106)

## [3.1.2](https://github.com/imaginary-cloud/CameraManager/tree/3.1.2) - 2017-05-02
### Changed

- New option to flip image took by front camera (pull request #104)
- Fixes possible hang after requesting permission (pull request #98)

## [3.1.1](https://github.com/imaginary-cloud/CameraManager/tree/3.1.1) - 2017-03-15
### Changed

- Refactor to avoid implicit unwrapped optionals (pull request #94)

## [3.1.0](https://github.com/imaginary-cloud/CameraManager/tree/3.1.0) - 2017-02-11
### Added

- Flip animation and tap to focus (pull request #72)
- Icons and splash image to example

## [3.0.0](https://github.com/imaginary-cloud/CameraManager/tree/3.0.0) - 2016-09-16
### Changed

- Syntax update for Swift 3.0.

## [2.2.4](https://github.com/imaginary-cloud/CameraManager/tree/2.2.4) - 2016-07-06
### Added

- Add error checking.

### Changed

- Fixes completion typos and suggests renamed functions.

## [2.2.3](https://github.com/imaginary-cloud/CameraManager/tree/2.2.3) - 2016-05-12
### Changed

- Fixed zoom in StillImage Mode.

- Minor refactoring

## [2.2.2](https://github.com/imaginary-cloud/CameraManager/tree/2.2.2) - 2016-03-07
### Added

- `CHANGELOG.md` file.

## [2.2.1](https://github.com/imaginary-cloud/CameraManager/tree/2.2.1) - 2016-03-02
### Added

- Initial support for the Swift Package Manager.

## [2.2.0](https://github.com/imaginary-cloud/CameraManager/tree/2.2.0) - 2016-02-19
### Added

- Zoom support.

### Changed

- Fixed spelling of `embeddingView`.

## [2.1.3](https://github.com/imaginary-cloud/CameraManager/tree/2.1.3) - 2016-01-08
### Changed

- No sound in video with more than 10 seconds fixed.

- Fixed `NewCameraOutputMode` not passed during init.

## [2.1.2](https://github.com/imaginary-cloud/CameraManager/tree/2.1.2) - 2015-12-24
### Added

- Property `cameraIsReady`.

- Completion block `addPreviewLayerToView`.

## [2.1.1](https://github.com/imaginary-cloud/CameraManager/tree/2.1.1) - 2015-12-11
### Added

- Ability to disable responding to device orientation changes.

## [2.1.0](https://github.com/imaginary-cloud/CameraManager/tree/2.1) - 2015-11-20
### Added

- Properties `recordedDuration` and `recordedFileSize`.

## [2.0.2](https://github.com/imaginary-cloud/CameraManager/tree/2.0.2) - 2015-11-17
### Fixed

- iOS 9.0.1 bug.

## [2.0.1](https://github.com/imaginary-cloud/CameraManager/tree/2.0.1) - 2015-09-17
### Changed

- Syntax updates.

## [2.0.0](https://github.com/imaginary-cloud/CameraManager/tree/2.0.0) - 2015-07-30
### Changed

- Syntax update for Swift 2.0.

## [1.0.14](https://github.com/imaginary-cloud/CameraManager/tree/1.0.14) - 2015-07-17
### Changed

- Small fixes.

## [1.0.13](https://github.com/imaginary-cloud/CameraManager/tree/1.0.13) - 2015-05-12
### Added

- Support for installing via Carthage.

- Property `hasFlash`.

### Changed

- Syntax update for Swift 1.2.

## [1.0.12](https://github.com/imaginary-cloud/CameraManager/tree/1.0.12) - 2015-03-23
### Added

- Incremental flash mode.

- Content localization.

### Changed

- Torch is set to correct state according to the current flash mode.

- `README.md` update.

## [1.0.11](https://github.com/imaginary-cloud/CameraManager/tree/1.0.11) - 2015-03-20
### Added

- Property `showAccessPermissionPopupAutomatically`, to determine if you want the user to be asked about camera permissions automatically or manually.

- Error handling in capture completion blocks.

## [1.0.10](https://github.com/imaginary-cloud/CameraManager/tree/1.0.10) - 2015-03-19
### Added

- Camera state returned when adding the preview layer.

### Changed

- `README.md` update.

## [1.0.9](https://github.com/imaginary-cloud/CameraManager/tree/1.0.9) - 2015-03-10
### Changed

- CameraManager class made public.

## [1.0.8](https://github.com/imaginary-cloud/CameraManager/tree/1.0.8) - 2015-02-24
### Fixed

- Wrong orientation when camera preview starts in landscape mode.

- Crash when trying to capture a still image.

- Orientation detection failure after stop and resume of a capture session.

- Bug which prevented from recording audio.

## [1.0.7](https://github.com/imaginary-cloud/CameraManager/tree/1.0.7) - 2014-10-30
### Added

- Version compatible with XCode 6.1.

### Changed

- `README.md` update.

- Swift syntax updates to resolve compile errors.

## [1.0.6](https://github.com/imaginary-cloud/CameraManager/tree/1.0.6) - 2014-10-28
### Added

- Check for valid capture session.

### Changed

- Fixed video orientation change.

## [1.0.5](https://github.com/imaginary-cloud/CameraManager/tree/1.0.5) - 2014-10-22
### Changed

- Enhanced Camera lifecyle.

- Orientation observers only added if needed.

## [1.0.4](https://github.com/imaginary-cloud/CameraManager/tree/1.0.4) - 2014-10-16
### Added

- Restart session.

### Changed

- `README.md` update.

## [1.0.3](https://github.com/imaginary-cloud/CameraManager/tree/1.0.3) - 2014-10-15
### Added

-  Property `writeFilesToPhoneLibrary` to conditionally write to user library.

### Changed

- Resources only recreated when needed.

- `README.md` update.

## [1.0.2](https://github.com/imaginary-cloud/CameraManager/tree/1.0.2) - 2014-10-15
### Added

- `CameraManager.podspec` file.

## [1.0.1](https://github.com/imaginary-cloud/CameraManager/tree/1.0.1) - 2014-10-15
### Changed

- Optional initializer for `addPreviewLayerToView`.

## [1.0.0](https://github.com/imaginary-cloud/CameraManager/tree/1.0.0) - 2014-10-15
### Added

- Front and back camera selection.

- Support for multiple flash modes.

- Video recording, with or without mic.

- Support for multiple camera output quality.

- Preview layer follows interface orientation changes.
