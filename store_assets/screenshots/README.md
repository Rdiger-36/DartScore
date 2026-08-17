# Store screenshots

Everything under this folder is generated. Do not edit a picture by hand, change
the code that produces it and run the two steps again.

```bash
tool/store_screenshots.sh
dart run tool/compose_store_screenshots.dart
```

The first step drives `integration_test/store_screenshots_test.dart` on four
simulators and emulators and writes `raw/`. The second step frames those into
the pictures that go into the two listings and writes `store/`. Composing needs
`rsvg-convert`:

```bash
brew install librsvg
```

## What is generated

`raw/<device>/<theme>/<language>/<screen>.png` holds the plain screenshots, in
both themes and both languages. `store/<device>/<language>/<n>_<screen>.png`
holds the framed pictures, numbered in the order they should be uploaded in.

Three pictures per device and language:

1. `modes`, the four game modes. One frame, centred, dark. It is the one that
   has to survive being a thumbnail, so nothing else competes with it.
2. `live`, an X01 leg with the checkout route on screen. Two frames, the dark
   one in front and the light one behind it, running off the right edge.
3. `summary`, the numbers after the game. Two frames again, this time with the
   light one in front, so the set does not end on three dark pictures.

The paired frames are the same screen in both themes on purpose: it says in one
picture that the app follows the system theme, and it costs no extra screen.
Frames are allowed to run off the canvas; a frame that ends inside the picture
reads as a screenshot pasted onto a poster.

Headlines, sublines and the frame geometry are all in `_kImages` at the top of
`tool/compose_store_screenshots.dart`. Changing the wording is one line.

## Sizes, and why these devices

| Folder | Device | Size | Store slot |
| --- | --- | --- | --- |
| `iphone` | iPhone 17 Pro Max | 1320x2868 | App Store, iPhone 6.9" |
| `ipad` | iPad Pro 13" | 2064x2752 | App Store, iPad 13" |
| `android_phone` | 1080x2400 phone | 1080x2160 | Google Play, phone |
| `android_tablet` | Pixel Tablet | 2560x1600 | Google Play, 10" tablet |

Apple asks for one iPhone size and one iPad size and scales them down for every
smaller device, so those two cover the whole listing.

The Android phone is the one whose canvas is not the size it was shot at. It
renders 1080x2400, and Google Play rejects a picture whose long side is more
than twice its short one, so the composer lays the frame out on 1080x2160
instead.

## Demo data

The match in the pictures is played by the test, not seeded from a fixture: two
generic players, 501, best of five legs, ending 3-1. The averages land in the
seventies and eighties because the scripted visits are ordinary club visits.
Nobody's real name appears anywhere.

## What is not automated

The feature graphic (`../feature_graphic.png`) is still made by hand, and so is
the App Store preview video, if one is ever made.
