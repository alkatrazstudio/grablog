# GrabLog - CHANGELOG


## v1.1.0 (June 22, 2026)

- Added: support for GitHub Actions (see README for an important note)
- Added: support for CHANGELOG.TXT files
- Changed: hide Composer package versions with known security advisories
- Changed: removed the commit hash for dev-master versions for Composer packages
- Changed: show max non-breaking version when exact-version constraint is set
- Fixed: parsing constraints for Composer
- Fixed: showing unavailable versions in Yarn
- Improved: change the text for some labels to be more understandable
- Improved: dim the version if it's the same as the current one
- Improved: make clickable elements have a hand cursor


## v1.0.1 (May 9, 2026)

- Fixed: cannot fetch changelogs from GitHub
- Fixed: macOS app archive contains duplicated libraries
- Changed: Help button is now called About


## v1.0.0 (Jan 1, 2026)

- Only internal changes


## v0.2.0 (June 12, 2025)

- Added: Yarn 2+ support
- Improved: the text in the changelogs is now selectable
- Improved: the links in the changelogs are now clickable


## v0.1.1 (July 20, 2024)

- Changed: support version query for Dart packages only from the pub.dev
- Fixed: scaling issues on Linux
- Fixed: the actual path to the project is not kept when using relative paths via command line
- Fixed: cannot open the directory from the recent directories list on macOS


## v0.1.0 (March 16, 2024)

- Initial release
