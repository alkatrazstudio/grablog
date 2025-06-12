# GrabLog

GrabLog shows what packages can be updated and then shows changelogs for each package.

<img src="screenshot.png?raw=true" alt="GrabLog main screen" title="GrabLog main screen" />


### Supported package managers

* Pub (Dart/Flutter)
* Composer (PHP)
* Yarn (JavaScript/NodeJS)
* Cargo (Rust)


### Supported operating systems

| OS           | Download                                                                                                                      | Comments                                                            |
|--------------|-------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------|
| Ubuntu 24.04 | [grablog-linux-v0.2.0.tar.xz](https://github.com/alkatrazstudio/grablog/releases/download/v0.2.0/grablog-linux-v0.2.0.tar.xz) | May work on other distributions                                     |
| macOS 15     | [grablog-macos-v0.2.0.pkg](https://github.com/alkatrazstudio/grablog/releases/download/v0.2.0/grablog-macos-v0.2.0.zip)       | Universal binary (x86_64 + arm64)                                   |
| Windows 11   | [grablog-windows-v0.2.0.zip](https://github.com/alkatrazstudio/grablog/releases/download/v0.2.0/grablog-windows-v0.2.0.zip)   | Install [vc_redist](https://aka.ms/vs/17/release/vc_redist.x64.exe) |


### Info

* This tool relies on website scraping and parsing, therefore it can stop working at any moment.

* You can pass a directory or a path to a lock file as a CLI argument.

* The network requests are cached until the end of the day.

* To build from the source, install and setup [Flutter](https://flutter.dev),
  then run `build.sh` (on Linux or macOS) or `build-windows.ps1` (on Windows).


### License

[AGPLv3](LICENSE.md)
