import 'dart:convert';
import 'dart:io';

/// Turns the raw screenshots into the pictures the two store listings show: six
/// pages per device and language, each one a headline, a subline and one or two
/// device frames on a coloured background.
///
/// Run it after `tool/store_screenshots.sh` has filled
/// `store_assets/screenshots/raw/`:
///
///     dart run tool/compose_store_screenshots.dart
///
/// It writes `store_assets/screenshots/store/<device>/<language>/`, numbered in
/// the order the pages should be uploaded in.
///
/// Composing goes through SVG and `rsvg-convert` (`brew install librsvg`)
/// rather than an image package, because the whole job is a gradient, a few
/// rounded rectangles, some bitmaps and a handful of lines of text. A renderer
/// that already does all of it is a smaller dependency than a pixel loop that
/// has to learn them.

/// The canvas each device's pages are rendered at.
///
/// These are the sizes the stores ask for, not the sizes the devices shoot at.
///
/// The iPhone shoots 1320x2868 and is laid out on 1284x2778, which is what the
/// App Store's iPhone slot takes: it accepts 1242x2688 or 1284x2778 and rejects
/// anything else, the shot's own size included.
///
/// The Android phone differs for its own reason: it renders 1080x2400, and
/// Google Play rejects a picture whose long side is more than twice its short
/// one, so its canvas is 1080x2160 and the screen is scaled to fit.
const _kCanvases = <String, ({int width, int height, String slot})>{
  'iphone':         (width: 1284, height: 2778, slot: 'App Store, iPhone 6.7"'),
  'ipad':           (width: 2064, height: 2752, slot: 'App Store, iPad 13"'),
  'android_phone':  (width: 1080, height: 2160, slot: 'Google Play, phone'),
  'android_tablet': (width: 2560, height: 1600, slot: 'Google Play, 10" tablet'),
};

/// The devices whose frames carry a drawn on island, because their screenshots
/// do not.
///
/// Only the iPhone. Its screenshots keep the safe area at the top free, so the
/// island lands on empty screen. Android runs the screenshot pass in immersive
/// mode, where the app paints all the way to the top edge and an island would
/// sit on the title of whatever screen is shown. A tablet gets none either: a
/// frame with an island reads as a phone that grew.
const _kNotched = {'iphone'};

/// One device frame on a page.
///
/// The geometry is given as fractions of the canvas, so the same numbers lay
/// out a tall phone and a wide tablet. A frame is allowed to reach past the
/// canvas: one that ends inside the picture reads as a screenshot pasted onto
/// a poster.
class _Frame {
  /// Which raw screenshot this frame shows, and in which theme.
  final String screen;
  final String theme;

  /// Frame width as a fraction of the canvas width. Ignored when [fit] is set.
  final double width;

  /// Centre x as a fraction of the canvas width.
  final double cx;

  /// Top edge as a fraction of the band the text leaves free, measured from
  /// the top of that band. A frame is allowed to reach past its bottom: one
  /// that ends inside the picture reads as a screenshot pasted onto a poster.
  final double top;

  /// Frame height as a fraction of the band, for the frames that have to stay
  /// clear of a line of text underneath them. The width follows from it, so a
  /// fitted frame is as large as the page has room for on every canvas.
  final double? fit;

  /// How far the frame is tilted, in degrees, turning clockwise around its own
  /// centre.
  final double rotate;

  /// Whether this frame stands behind the one in front of it, which is drawn
  /// dimmed so the eye picks the front one first.
  final bool behind;

  const _Frame({
    required this.screen,
    required this.theme,
    required this.cx,
    required this.top,
    this.width = 0,
    this.fit,
    this.rotate = 0,
    this.behind = false,
  });
}

/// The words on one page, in one language.
///
/// The lines are split by hand: SVG has no line breaking of its own, and a
/// headline that wraps where the renderer feels like it reads worse than one
/// broken where the sentence does.
class _Copy {
  /// Bold lines at the top of the page.
  final List<String> headline;

  /// A quieter line under the headline.
  final String? subline;

  /// Bold lines at the foot of the page, for the pages whose statement belongs
  /// under the picture rather than over it.
  final List<String> footline;

  /// A quieter line at the very bottom.
  final String? footnote;

  const _Copy({
    this.headline = const [],
    this.subline,
    this.footline = const [],
    this.footnote,
  });
}

/// One store page: its background, its frames and its words in both languages.
class _Page {
  final String name;

  /// Whether the page is red or blue. They alternate, so a listing reads as a
  /// set rather than as six pictures that happen to share a font.
  final bool blue;

  /// Back to front. A frame later in the list is drawn over the ones before it.
  final List<_Frame> portrait;
  final List<_Frame> landscape;

  final _Copy de;
  final _Copy en;

  const _Page({
    required this.name,
    required this.blue,
    required this.portrait,
    required this.landscape,
    required this.de,
    required this.en,
  });
}

/// The six pages, in upload order.
///
/// The first one stands alone and centred, because it is the one a browsing
/// reader sees as a thumbnail and it has to survive being small. The pages
/// after it each make one point: two players or one, the numbers, the heatmap,
/// the other modes, and that the app follows the system theme.
const _kPages = <_Page>[
  // ── 1. The scorer itself ──────────────────────────────────────────────────
  _Page(
    name: 'intro',
    blue: false,
    portrait: [
      _Frame(screen: 'live_duo', theme: 'dark', width: 0.82, cx: 0.5, top: 0.07),
    ],
    landscape: [
      _Frame(screen: 'live_duo', theme: 'dark', fit: 0.96, cx: 0.5, top: 0.02),
    ],
    de: _Copy(headline: ['Der smarte Weg,', 'Darts zu spielen']),
    en: _Copy(headline: ['The Smarter Way', 'to Play Darts']),
  ),
  // ── 2. Solo and against somebody ──────────────────────────────────────────
  _Page(
    name: 'players',
    blue: true,
    portrait: [
      _Frame(screen: 'live_duo',  theme: 'light', fit: 0.66, cx: 0.33,
          top: 0.0, rotate: 7, behind: true),
      _Frame(screen: 'live_solo', theme: 'dark',  fit: 0.66, cx: 0.67,
          top: 0.24, rotate: 7),
    ],
    landscape: [
      _Frame(screen: 'live_duo',  theme: 'light', fit: 0.70, cx: 0.31,
          top: 0.0, rotate: 8, behind: true),
      _Frame(screen: 'live_solo', theme: 'dark',  fit: 0.70, cx: 0.69,
          top: 0.24, rotate: 8),
    ],
    de: _Copy(
      headline: ['Allein oder zu zweit'],
      footline: ['Kostenlos, ohne Werbung'],
    ),
    en: _Copy(
      headline: ['Play Solo or Multiplayer'],
      footline: ['All Free, No Ads'],
    ),
  ),
  // ── 3. The numbers ────────────────────────────────────────────────────────
  _Page(
    name: 'stats',
    blue: false,
    portrait: [
      _Frame(screen: 'stats_header', theme: 'light', width: 0.74, cx: 0.5,
          top: 0.02),
    ],
    landscape: [
      _Frame(screen: 'stats_header', theme: 'light', fit: 0.96, cx: 0.5,
          top: 0.02),
    ],
    de: _Copy(
      headline: ['Sieh, wie du', 'besser wirst'],
      subline:  'Jeder Wurf landet in deiner Statistik',
    ),
    en: _Copy(
      headline: ['See Yourself', 'Improve'],
      subline:  'Your performance, broken down in detail',
    ),
  ),
  // ── 4. The heatmap, with the words underneath ─────────────────────────────
  _Page(
    name: 'heatmap',
    blue: true,
    portrait: [
      _Frame(screen: 'stats_heatmap', theme: 'dark', fit: 1.0, cx: 0.5,
          top: 0.0),
    ],
    landscape: [
      _Frame(screen: 'stats_heatmap', theme: 'dark', fit: 1.0, cx: 0.5,
          top: 0.0),
    ],
    de: _Copy(
      footline: ['Deine Scheibe,', 'auf einen Blick'],
      footnote: 'Die Heatmap zeigt, wo deine Darts landen',
    ),
    en: _Copy(
      footline: ['Your Dartboard,', 'Visualized'],
      footnote: 'See your accuracy at a glance and sharpen your aim',
    ),
  ),
  // ── 5. The other three modes ──────────────────────────────────────────────
  _Page(
    name: 'modes',
    blue: false,
    portrait: [
      _Frame(screen: 'modes', theme: 'dark', fit: 0.90, cx: 0.52, top: 0.03,
          rotate: -8),
    ],
    landscape: [
      _Frame(screen: 'modes', theme: 'dark', fit: 0.84, cx: 0.52, top: 0.08,
          rotate: -8),
    ],
    de: _Copy(
      headline: ['Noch mehr', 'Spielmodi'],
      footnote: 'Cricket, Shanghai und Around the Clock sind dabei',
    ),
    en: _Copy(
      headline: ['Explore other', 'Game Modes'],
      footnote: 'There are many more ways to play Darts!',
    ),
  ),
  // ── 6. Both themes ────────────────────────────────────────────────────────
  _Page(
    name: 'themes',
    blue: true,
    portrait: [
      _Frame(screen: 'live_duo', theme: 'light', fit: 0.62, cx: 0.33,
          top: 0.02, rotate: 7, behind: true),
      _Frame(screen: 'live_duo', theme: 'dark',  fit: 0.62, cx: 0.67,
          top: 0.28, rotate: 7),
    ],
    landscape: [
      _Frame(screen: 'live_duo', theme: 'light', fit: 0.74, cx: 0.31,
          top: 0.0, rotate: 8, behind: true),
      _Frame(screen: 'live_duo', theme: 'dark',  fit: 0.74, cx: 0.69,
          top: 0.22, rotate: 8),
    ],
    de: _Copy(headline: ['Hell oder dunkel,', 'ganz wie du magst']),
    en: _Copy(headline: ['Switch between light', 'and dark mode']),
  ),
];

/// Where the raw screenshots are read from.
const _kRawRoot = 'store_assets/screenshots/raw';

/// Where the composed pages are written to.
const _kStoreRoot = 'store_assets/screenshots/store';

Future<void> main(List<String> args) async {
  if (!await _hasRsvg()) {
    stderr.writeln('rsvg-convert is missing. Install it with: brew install librsvg');
    exit(1);
  }

  var written = 0;
  for (final device in _kCanvases.keys) {
    final canvas = _kCanvases[device]!;
    final landscape = canvas.width > canvas.height;

    for (final language in const ['de', 'en']) {
      for (var i = 0; i < _kPages.length; i++) {
        final page   = _kPages[i];
        final frames = landscape ? page.landscape : page.portrait;

        final shots = <String, ({({int width, int height}) size, String data})>{};
        var missing = false;
        for (final frame in frames) {
          final key = '${frame.screen}_${frame.theme}';
          if (shots.containsKey(key)) continue;
          final raw = File('$_kRawRoot/$device/${key}_$language.png');
          if (!raw.existsSync()) {
            stderr.writeln('missing, skipped: ${raw.path}');
            missing = true;
            break;
          }
          final bytes = await raw.readAsBytes();
          shots[key] = (size: _pngSize(bytes), data: base64Encode(bytes));
        }
        if (missing) continue;

        final out = File('$_kStoreRoot/$device/$language/'
            '${i + 1}_${page.name}.png');
        await out.parent.create(recursive: true);
        await _render(
          out:     out,
          canvas:  canvas,
          device:  device,
          page:    page,
          frames:  frames,
          shots:   shots,
          copy:    language == 'de' ? page.de : page.en,
        );
        written++;
        stdout.writeln('${out.path}  (${canvas.slot})');
      }
    }
  }

  stdout.writeln('\n$written pages written to $_kStoreRoot/.');
}

/// Renders one page.
Future<void> _render({
  required File out,
  required ({int width, int height, String slot}) canvas,
  required String device,
  required _Page page,
  required List<_Frame> frames,
  required Map<String, ({({int width, int height}) size, String data})> shots,
  required _Copy copy,
}) async {
  final svg = _svg(
    canvas: canvas,
    device: device,
    page:   page,
    frames: frames,
    shots:  shots,
    copy:   copy,
  );

  final temp = File('${Directory.systemTemp.path}/${out.uri.pathSegments.last}.svg');
  await temp.writeAsString(svg);
  final result = await Process.run('rsvg-convert', [
    '--width=${canvas.width}',
    '--height=${canvas.height}',
    '--format=png',
    '--output=${out.path}',
    temp.path,
  ]);
  await temp.delete();

  if (result.exitCode != 0) {
    throw StateError('rsvg-convert failed on ${out.path}: ${result.stderr}');
  }
}

/// Builds the SVG for one page.
String _svg({
  required ({int width, int height, String slot}) canvas,
  required String device,
  required _Page page,
  required List<_Frame> frames,
  required Map<String, ({({int width, int height}) size, String data})> shots,
  required _Copy copy,
}) {
  final w = canvas.width.toDouble();
  final h = canvas.height.toDouble();
  final landscape = w > h;
  final short = w < h ? w : h;

  // ── Type ──
  //
  // rsvg has no text measuring of its own, so a line that would run off the
  // canvas is caught by an estimate: a bold line of this typeface runs at about
  // half its font size per character. German says the same thing in more
  // letters than English does, and this is what keeps both inside the picture
  // without a second set of sizes per language.
  var headlineSize = short * (landscape ? 0.070 : 0.078);
  final headlineChars = [...copy.headline, ...copy.footline]
      .fold<int>(0, (longest, line) => line.length > longest ? line.length : longest);
  final headlineRoom = w * 0.86;
  if (headlineChars * headlineSize * 0.52 > headlineRoom) {
    headlineSize = headlineRoom / (headlineChars * 0.52);
  }

  var sublineSize = headlineSize * 0.40;
  final sublineChars = [copy.subline, copy.footnote]
      .whereType<String>()
      .fold<int>(0, (longest, line) => line.length > longest ? line.length : longest);
  final sublineRoom = w * 0.88;
  if (sublineChars * sublineSize * 0.48 > sublineRoom) {
    sublineSize = sublineRoom / (sublineChars * 0.48);
  }

  final lineHeight = headlineSize * 1.14;

  final text = StringBuffer();

  // Where the picture may start and where it has to end: everything the text
  // does not need. Both edges are measured off the lines that were actually
  // written, so a page with one headline gives its frames more room than a page
  // with two and a subline, on every canvas and in both languages.
  final headTop = h * (landscape ? 0.075 : 0.055);
  var bandTop    = headTop;
  var bandBottom = h;

  for (var i = 0; i < copy.headline.length; i++) {
    text.writeln('  <text x="${_n(w / 2)}" y="${_n(headTop + lineHeight * (i + 1))}" '
        'text-anchor="middle" class="headline">${_escape(copy.headline[i])}</text>');
    bandTop = headTop + lineHeight * (i + 1) + headlineSize * 0.30;
  }
  if (copy.subline != null) {
    // Measured from the last headline baseline: its descender, a gap, and the
    // subline's own ascender. Anything less and the two lines touch.
    final y = headTop +
        lineHeight * copy.headline.length +
        headlineSize * 0.62 +
        sublineSize * 0.80;
    text.writeln('  <text x="${_n(w / 2)}" y="${_n(y)}" '
        'text-anchor="middle" class="subline">${_escape(copy.subline!)}</text>');
    bandTop = y + sublineSize * 0.40;
  }
  bandTop += h * 0.035;

  // The foot of the page is built upwards from the bottom margin, so a page
  // with a footnote and one without both end at the same distance from the
  // edge.
  var footBase = h * (landscape ? 0.925 : 0.945);
  if (copy.footnote != null) {
    text.writeln('  <text x="${_n(w / 2)}" y="${_n(footBase)}" '
        'text-anchor="middle" class="subline">${_escape(copy.footnote!)}</text>');
    bandBottom = footBase - sublineSize * 0.90;
    footBase -= sublineSize * 0.80 + headlineSize * 0.55;
  }
  for (var i = copy.footline.length - 1; i >= 0; i--) {
    text.writeln('  <text x="${_n(w / 2)}" y="${_n(footBase)}" '
        'text-anchor="middle" class="headline">${_escape(copy.footline[i])}</text>');
    bandBottom = footBase - headlineSize * 0.92;
    footBase -= lineHeight;
  }
  if (copy.footnote != null || copy.footline.isNotEmpty) {
    bandBottom -= h * 0.030;
  }

  final band = bandBottom - bandTop;

  // ── Device frames ──
  final clips  = StringBuffer();
  final bodies = StringBuffer();

  for (var i = 0; i < frames.length; i++) {
    final frame = frames[i];
    final shot  = shots['${frame.screen}_${frame.theme}']!;

    // A fitted frame is given as the share of the band its height may take, and
    // its width follows from the shot it shows: the bezel is a share of the
    // width, so height is width times (0.956 * aspect + 0.044), and the width
    // is that read backwards.
    final aspect = shot.size.height / shot.size.width;
    final frameW = frame.fit == null
        ? w * frame.width
        : band * frame.fit! / (0.956 * aspect + 0.044);
    final frameX = w * frame.cx - frameW / 2;
    final frameY = bandTop + band * frame.top;

    // The bezel is a share of the frame, so it stays a bezel rather than
    // becoming a hairline on a small canvas and a slab on a large one.
    final bezel   = frameW * 0.022;
    final screenW = frameW - bezel * 2;
    final screenH = screenW * aspect;
    final frameH  = screenH + bezel * 2;
    final screenX = frameX + bezel;
    final screenY = frameY + bezel;

    final frameRadius  = frameW * 0.062;
    final screenRadius = frameRadius - bezel * 0.7;

    clips.writeln('''
    <clipPath id="screen$i" clipPathUnits="userSpaceOnUse">
      <rect x="${_n(screenX)}" y="${_n(screenY)}"
            width="${_n(screenW)}" height="${_n(screenH)}"
            rx="${_n(screenRadius)}" ry="${_n(screenRadius)}"/>
    </clipPath>''');

    // The notch is drawn on rather than shot: a simulator screenshot is the
    // whole screen, so a frame without one shows a phone nobody owns.
    final notch = StringBuffer();
    if (_kNotched.contains(device)) {
      final notchW = screenW * 0.26;
      final notchH = screenW * 0.072;
      notch.writeln('''
    <rect x="${_n(screenX + (screenW - notchW) / 2)}" y="${_n(screenY + notchH * 0.42)}"
          width="${_n(notchW)}" height="${_n(notchH)}"
          rx="${_n(notchH / 2)}" ry="${_n(notchH / 2)}" fill="#0A0A0C"/>''');
    }

    // A frame standing behind another one is pushed back with a scrim rather
    // than with a blur: it stays readable as the same app in the other theme,
    // which is the whole point of showing it, while the eye still lands on the
    // frame in front.
    final scrim = frame.behind
        ? '''
    <rect x="${_n(frameX)}" y="${_n(frameY)}"
          width="${_n(frameW)}" height="${_n(frameH)}"
          rx="${_n(frameRadius)}" ry="${_n(frameRadius)}"
          fill="#05050A" fill-opacity="0.14"/>'''
        : '';

    final turn = frame.rotate == 0
        ? ''
        : ' transform="rotate(${_n(frame.rotate)}, '
            '${_n(frameX + frameW / 2)}, ${_n(frameY + frameH / 2)})"';

    bodies.writeln('''
  <g$turn filter="url(#drop)">
    <rect x="${_n(frameX)}" y="${_n(frameY)}"
          width="${_n(frameW)}" height="${_n(frameH)}"
          rx="${_n(frameRadius)}" ry="${_n(frameRadius)}"
          fill="#0A0A0C" stroke="#3A3A3E" stroke-width="${_n(bezel * 0.30)}"/>
    <image x="${_n(screenX)}" y="${_n(screenY)}"
           width="${_n(screenW)}" height="${_n(screenH)}"
           clip-path="url(#screen$i)"
           xlink:href="data:image/png;base64,${shot.data}"/>
${notch.toString().trimRight()}
${scrim.trimRight()}
  </g>''');
  }

  final (inner, outer) = page.blue
      ? ('#2F41C4', '#0A1250')
      : ('#F04A45', '#A8121C');

  return '''
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="${canvas.width}" height="${canvas.height}"
     viewBox="0 0 ${canvas.width} ${canvas.height}">
  <defs>
    <radialGradient id="bg" cx="0.5" cy="0.42" r="0.95">
      <stop offset="0" stop-color="$inner"/>
      <stop offset="1" stop-color="$outer"/>
    </radialGradient>
    <filter id="drop" x="-25%" y="-25%" width="150%" height="150%">
      <feDropShadow dx="0" dy="${_n(short * 0.012)}"
                    stdDeviation="${_n(short * 0.016)}"
                    flood-color="#000000" flood-opacity="0.45"/>
    </filter>
$clips  </defs>
  <style>
    .headline, .subline {
      font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
    }
    .headline {
      font-weight: 800;
      font-size: ${_n(headlineSize)}px;
      fill: #FFFFFF;
      letter-spacing: ${_n(headlineSize * -0.020)}px;
    }
    .subline {
      font-weight: 400;
      font-size: ${_n(sublineSize)}px;
      fill: #FFFFFF;
      fill-opacity: 0.92;
    }
  </style>

  <rect width="100%" height="100%" fill="url(#bg)"/>

$text
$bodies</svg>
''';
}

/// Reads width and height out of a PNG's IHDR chunk.
///
/// A PNG always opens with an eight byte signature and an IHDR whose first two
/// fields are the dimensions, so this is the whole format that needs decoding
/// here: the pixels are handed to the renderer untouched.
({int width, int height}) _pngSize(List<int> bytes) {
  if (bytes.length < 24) throw StateError('not a PNG');
  int at(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
  return (width: at(16), height: at(20));
}

/// Whether `rsvg-convert` is on the path.
Future<bool> _hasRsvg() async {
  try {
    final result = await Process.run('rsvg-convert', ['--version']);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Formats [value] for SVG, without a trailing string of decimals.
String _n(double value) => value.toStringAsFixed(2);

/// Escapes the characters that would end an SVG text node early.
String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
