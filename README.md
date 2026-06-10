# TranslateD

Menu bar translator for macOS, inspired by compact translator popovers.

## Run

```bash
swift run TranslateD
```

The app appears in the macOS menu bar. Open the menu bar icon to translate text, paste-and-translate, or open settings.

## Build and Install to Applications

Build the macOS app bundle:

```bash
./scripts/build-app.sh
```

Install the built app into `/Applications`:

```bash
rm -rf /Applications/TranslateD.app
cp -R dist/TranslateD.app /Applications/TranslateD.app
```

Open the installed app:

```bash
open /Applications/TranslateD.app
```

## Features

- Google Translate-backed translation.
- Menu bar popover translator.
- Settings window with startup, screenshot, popup, paste translate, OCR language, and automatic Chinese-English options.
- Global shortcuts:
  - `Control + F`: select a screen area, OCR it, and translate.
  - `Control + D`: show popup.
- Paste translate is available from the popover clipboard button. `Control + C` is not registered globally so Terminal keeps its normal interrupt shortcut.
- OCR via Apple's Vision framework.

## Notes

The translation call uses Google's public web endpoint. For production distribution, replace it with an official API key-backed provider.
