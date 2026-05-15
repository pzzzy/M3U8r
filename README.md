# M3U8r

M3U8r is a small, native iOS player for HTTP Live Streaming (`.m3u8`) and other media URLs supported by `AVPlayer`.

It is built with SwiftUI and `AVPlayerViewController`, using the system player for playback controls, Picture in Picture, background audio, and Now Playing integration.

## Features

- Paste and play a stream URL from the clipboard
- Manually enter HTTP or HTTPS stream URLs
- Recent stream history stored locally on device
- Picture in Picture support through the standard iOS player
- Background audio playback for compatible streams
- No analytics, ads, tracking, accounts, or third-party SDKs

## Requirements

- Xcode 26 or newer
- iOS 16.0 or newer
- A physical device is recommended for final Picture in Picture and background audio validation

## Build

Open `M3U8r.xcodeproj` in Xcode and run the `M3U8r` scheme.

For a command-line Release build without signing:

```sh
xcodebuild \
  -project M3U8r.xcodeproj \
  -scheme M3U8r \
  -configuration Release \
  -sdk iphoneos \
  -arch arm64 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Privacy

M3U8r does not collect user data. Stream history is stored locally with `UserDefaults` and can be cleared in the app. Clipboard contents are only read when the user taps Paste & Play.

The app includes a privacy manifest declaring its local `UserDefaults` usage.

## Network Security

The app uses App Transport Security's media-specific allowance so AVFoundation can play media streams that are not fully ATS-compliant. General arbitrary networking is not enabled.

## Contributing

Issues and pull requests are welcome. Please keep changes focused, test playback behavior on a real device when possible, and avoid adding third-party SDKs unless there is a strong reason.

## License

M3U8r is available under the MIT License. See [LICENSE](LICENSE).
