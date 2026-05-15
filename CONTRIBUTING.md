# Contributing

Thanks for helping improve M3U8r.

## Development

1. Fork the repository.
2. Create a focused branch for your change.
3. Build the app in Xcode or with `xcodebuild`.
4. Test playback flows on a real iOS device when the change touches media playback, Picture in Picture, audio sessions, or background behavior.
5. Open a pull request with a clear description of what changed and how you verified it.

## Guidelines

- Keep the app native and lightweight.
- Prefer Apple frameworks and platform behavior over custom playback infrastructure.
- Do not add analytics, advertising, tracking, or account systems.
- Keep privacy-sensitive behavior user-initiated and clearly scoped.
- Include screenshots or screen recordings for visible UI changes when helpful.

## Release Checklist

- Release build succeeds.
- App Store validation produces no actionable warnings.
- Paste, manual URL entry, history, playback, PiP, and background audio are tested.
- Privacy manifest and App Store privacy labels still match the app behavior.
