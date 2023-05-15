# Telereso

[![CI Status](https://img.shields.io/travis/telereso/ios.svg?style=flat)](https://app.travis-ci.com/github/telereso/ios)
[![Version](https://img.shields.io/cocoapods/v/Telereso.svg?style=flat)](https://cocoapods.org/pods/Telereso)
[![License](https://img.shields.io/cocoapods/l/Telereso.svg?style=flat)](https://cocoapods.org/pods/Telereso)
[![Platform](https://img.shields.io/cocoapods/p/Telereso.svg?style=flat)](https://cocoapods.org/pods/Telereso)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

Telereso is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Telereso'
```

## License

Telereso is available under the MIT license. See the LICENSE file for more info.


## Publish 
* make sure to register your email locally first 
  ```shell
  pod trunk register <email>
  ```
* Update [Telereso.podspec](Telereso.podspec) 
  `s.version          = '<new-version>'`
* Create Tag `<new-version>`
* Run command
  ```shell
  pod trunk push Telereso.podspec
  ```