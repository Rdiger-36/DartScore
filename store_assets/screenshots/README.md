# Store screenshots

Everything under this folder is generated. Do not edit a picture by hand, change
the code that produces it and run the two steps again.

```bash
tool/store_screenshots.sh
dart run tool/compose_store_screenshots.dart
```

The first step drives `integration_test/store_screenshots_test.dart` on five
simulators and emulators, the iPhone Duo twice, and writes `raw/`. The second step frames those into
the pictures that go into the two listings and writes `store/`. Composing needs
`rsvg-convert`:

```bash
brew install librsvg
```

## What is generated

`raw/<device>/<screen>_<theme>_<language>.png` holds the plain screenshots, in
both themes and both languages. Theme and language are part of the file name, so
a raw picture is still identifiable once it has been copied out of its folder.

`store/<device>/<language>/<n>_<page>_<device>_<language>.png` holds the
finished pages, numbered in the order they should be uploaded in. Device and
language are in the name too, so a page dragged into App Store Connect or the
Play Console still says which slot and which listing it belongs to.

`store/app_store_artwork/<language>/` holds the two App Store pictures that are
not screenshots, see below.

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
5. `modes`, the mode selection with all five modes, one tilted frame.
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
| `iphone` | iPhone 17 Pro Max | 1320x2868 | App Store, iPhone 6.9" |
| `iphone_63` | laid out from `iphone` | 1206x2622 | App Store, iPhone 6.3" |
| `iphone_duo` | iPhone Duo, unfolded | 2853x2007 | App Store, iPhone Duo inner display |
| `iphone_duo_cover` | iPhone Duo, folded | 1398x2034 | App Store, iPhone Duo outer display |
| `ipad` | iPad Pro 13" | 2064x2752 | App Store, iPad 13" |
| `android_phone` | 1080x2400 phone | 1080x2160 | Google Play, phone |
| `android_tablet` | Pixel Tablet | 2560x1600 | Google Play, 10" tablet |

Apple scales the largest iPad size down for every smaller iPad. The iPhone gets
two sizes: App Store Connect has a 6.3" slot of its own next to the 6.9" one,
and that slot takes only 1206x2622 or 1179x2556. That canvas reuses the 6.9" shots (`_kShotFrom` in the
composer), so the run needs no extra simulator for it.

The iPhone Duo has its own two slots, one per display, and is not scaled from
any other iPhone. Both are optional today; Apple's page says they become
required in April 2027 for apps built with the iOS 27.1 SDK or later, and a
listing that has them shows a badge saying the app is made for the Duo. The
inner display lies on its side when unfolded, so its pages are landscape. The
outer display only gets the first page and the modes, two pictures that show
the app fits the folded phone too; which pages a device gets is `_kPagesFor`
in the composer.

`simctl` cannot fold the Duo. Since Xcode 27 the simulator window is Device Hub,
and that is where it is folded and unfolded; the run stops before each Duo pass
and asks for it. The app always draws on the display in use. Both displays keep
a strip on the right free for the time and the battery, which is why the app
does not reach the right edge on either. A Flutter screenshot leaves that strip
empty, which reads as a thick bezel, so the composer lays the system's status
cluster over each Duo shot from `status/<device>_<theme>.png`. Those four
transparent pictures are not made by the run: they were cut once from a
`simctl io screenshot` of each display in dark and light appearance, keeping
only the pixels that differ from the background. Redo them only if Apple
changes the status cluster.

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

## App Store header and search result

Since iOS 27 a product page can open with a wide header picture, and a search
result can show its own picture instead of the first screenshots. Both are
uploaded to the Asset Library in App Store Connect, which reviews them on their
own, without a new version of the app.

| File | Size | Slot |
| --- | --- | --- |
| `header_<language>.png` | 3840x1646, 21:9 | Product page header |
| `search_<language>.png` | 3840x2560, 3:2 | Search results |

They are composed from the same raw screenshots as the pages and live in
`_kArtwork` in the composer. Both show every Apple device the app runs on: the
header is a fan with the unfolded Duo in the middle, two iPhones beside it and
the iPad and the folded Duo at the edges; the search result has the iPad, an
iPhone and both Duo displays under the headline.
The header carries no words, because Apple lays the icon, the name and the Get
button over it and asks for the point of the picture to stay in the middle. The
search result carries the headline of the first page. Apple's rules for both:
no prices, no links, no logos of other platforms, nothing above a 4+ rating, and
every language the app supports.

## What is not automated

The feature graphic (`../feature_graphic.png`) is still made by hand, and so is
the App Store preview video, if one is ever made. Its three phones are the dark
`modes`, `live_duo` and `stats_heatmap` shots of `raw/android_phone/`, embedded
in `feature_graphic(_de).svg`; swap them there and render with `rsvg-convert`.
Save the JPEG without Exif data or a colour profile: the Play Console turned
down one that `sips` had written, at the right size and format, and took the
same picture saved plainly.
