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

`raw/<device>/<screen>_<theme>_<language>.png` holds the plain screenshots, in
both themes and both languages. Theme and language are part of the file name, so
a raw picture is still identifiable once it has been copied out of its folder.

`store/<device>/<language>/<n>_<page>.png` holds the finished pages, numbered in
the order they should be uploaded in.

Six pages per device and language, red and blue alternating so a listing reads
as one set:

1. `intro`, the X01 scorer with the checkout route on screen. One frame, straight,
   dark. It is the one that has to survive being a thumbnail, so nothing else
   competes with it.
2. `players`, the two player leg beside the solo leg, two tilted frames, one
   theme each.
3. `stats`, the top of a player's statistics: the average, the highlight tiles
   and the totals.
4. `heatmap`, the dartboard heatmap, with the words under the picture instead of
   over it.
5. `modes`, the mode selection, one tilted frame.
6. `themes`, the same screen twice, light and dark, which says in one picture
   that the app follows the system theme.

Frames are not placed on the canvas but into the band the text leaves free, so
a page with one headline gives its picture more room than a page with two lines
and a subline, and the German and the English page each get the room their own
words leave. A frame given a `fit` takes that share of the band and works out its
own width; one given a `width` may run off the bottom edge, which is what the
first and third page do on purpose. A frame that ends inside the picture reads
as a screenshot pasted onto a poster. The island is drawn on rather than
shot, and only on the iPhone: its screenshots leave the safe area at the top
free, while the Android pass runs in immersive mode and paints to the very edge.

Headlines, sublines and the frame geometry are all in `_kPages` at the top of
`tool/compose_store_screenshots.dart`. Changing the wording is one line. A line
too long for its canvas is scaled down rather than clipped, which is what lets
the German and the English page share one layout.

## Sizes, and why these devices

| Folder | Device | Size | Store slot |
| --- | --- | --- | --- |
| `iphone` | iPhone 17 Pro Max | 1284x2778 | App Store, iPhone 6.7" |
| `ipad` | iPad Pro 13" | 2064x2752 | App Store, iPad 13" |
| `android_phone` | 1080x2400 phone | 1080x2160 | Google Play, phone |
| `android_tablet` | Pixel Tablet | 2560x1600 | Google Play, 10" tablet |

Apple asks for one iPhone size and one iPad size and scales them down for every
smaller device, so those two cover the whole listing. The iPhone pages are laid
out on 1284x2778 rather than on the 1320x2868 the simulator shoots: the App Store
iPhone slot takes 1242x2688 or 1284x2778 and rejects every other size, the shot's
own included.

The Android phone is the one whose canvas is not the size it was shot at. It
renders 1080x2400, and Google Play rejects a picture whose long side is more
than twice its short one, so the composer lays the frame out on 1080x2160
instead.

## Demo data

Nothing is seeded from a fixture. The run plays twelve 501 games between two
generic players first, dart by dart, and the statistics pictures show what those
games produced. Every dart is aimed at what the score in front of it asks for and
then scattered by an accuracy the run holds per player, so the averages land in
the fifties and low sixties, the checkout rate around a third, and the busts and
missed doubles are thrown rather than counted out. Three maximums are placed by
hand, because over a season this size a 180 is a coin flip and the highlight
tiles should not read as zeroes on one run and as twos on the next.

The season is played in one go and its timestamps are rewritten afterwards, so
the games sit across the last six weeks instead of all on today. That is what
fills the week comparison card. It is the one place in the project that writes
SQL outside `db_helper.dart`, and it lives in the screenshot test only.

The two live screens are scripted rather than thrown: the leg on them ends with
one player on 141 and one on 180, and the solo leg on 96. They are shot after the
statistics, so the unfinished legs are not part of the numbers.

Nobody's real name appears anywhere.

## What is not automated

The feature graphic (`../feature_graphic.png`) is still made by hand, and so is
the App Store preview video, if one is ever made.
