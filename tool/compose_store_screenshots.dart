import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Turns the raw screenshots into the pictures the two store listings show:
/// one or two device frames on a background, under a headline and a subline.
///
/// Run it after `tool/store_screenshots.sh` has filled
/// `store_assets/screenshots/raw/`:
///
///     dart run tool/compose_store_screenshots.dart
///
/// It writes `store_assets/screenshots/store/<device>/<language>/`, numbered in
/// the order the pictures should be uploaded in.
///
/// Composing goes through SVG and `rsvg-convert` (`brew install librsvg`)
/// rather than an image package, because the whole job is a gradient, a few
/// rounded rectangles, two bitmaps and three lines of text. A renderer that
/// already does all of it is a smaller dependency than a pixel loop that has to
/// learn them.

/// The canvas each device's pictures are rendered at.
///
/// These are the sizes the stores ask for, not the sizes the devices shoot at.
/// The Android phone is the one that differs: it renders 1080x2400, and Google
/// Play rejects a picture whose long side is more than twice its short one, so
/// its canvas is 1080x2160 and the screen is scaled to fit.
const _kCanvases = <String, ({int width, int height, String slot})>{
  'iphone':         (width: 1320, height: 2868, slot: 'App Store, iPhone 6.9"'),
  'ipad':           (width: 2064, height: 2752, slot: 'App Store, iPad 13"'),
  'android_phone':  (width: 1080, height: 2160, slot: 'Google Play, phone'),
  'android_tablet': (width: 2560, height: 1600, slot: 'Google Play, 10" tablet'),
};

/// One device frame in a picture.
///
/// The geometry is given as fractions of the canvas, so the same numbers lay
/// out a tall phone and a wide tablet. A layer is allowed to reach past the
/// canvas: a frame that runs off the bottom or the side edge is what keeps the
/// picture from reading as a screenshot pasted onto a poster.
class _Layer {
  /// Which raw screenshot this frame shows.
  final String screen;

  /// Which theme of it, `dark` or `light`.
  final String theme;

  /// Frame width, as a fraction of the canvas width.
  final double width;

  /// Left edge, as a fraction of the canvas width.
  final double x;

  /// Top edge below the text block, as a fraction of the canvas height.
  final double y;

  /// Whether this frame stands behind the one in front of it, which is drawn
  /// dimmed so the eye picks the front one first.
  final bool behind;

  const _Layer({
    required this.screen,
    required this.theme,
    required this.width,
    required this.x,
    required this.y,
    this.behind = false,
  });
}

/// One store picture: its layers and its text in both languages.
class _Image {
  final String name;

  /// Back to front. A layer later in the list is drawn over the ones before it.
  final List<_Layer> portrait;
  final List<_Layer> landscape;

  final List<String> headlineDe;
  final String       sublineDe;
  final List<String> headlineEn;
  final String       sublineEn;

  const _Image({
    required this.name,
    required this.portrait,
    required this.landscape,
    required this.headlineDe,
    required this.sublineDe,
    required this.headlineEn,
    required this.sublineEn,
  });
}

/// The pictures, in upload order.
///
/// The first one stands alone and centred, because it is the one a browsing
/// reader sees as a thumbnail and it has to survive being small. The other two
/// carry the same screen twice, once dark and once light, which says in one
/// picture that the app follows the system theme.
///
/// The headline lines are split by hand: SVG has no line breaking of its own,
/// and a headline that wraps where the renderer feels like it reads worse than
/// one broken where the sentence does.
const _kImages = <_Image>[
  _Image(
    name: 'modes',
    portrait: [
      _Layer(screen: 'modes', theme: 'dark', width: 0.78, x: 0.11, y: 0.0),
    ],
    landscape: [
      _Layer(screen: 'modes', theme: 'dark', width: 0.70, x: 0.15, y: 0.0),
    ],
    headlineDe: ['Vier Spielmodi,', 'ein Zähler'],
    sublineDe:  'X01, Cricket, Shanghai und Around the Clock',
    headlineEn: ['Four game modes,', 'one scorer'],
    sublineEn:  'X01, Cricket, Shanghai and Around the Clock',
  ),
  _Image(
    name: 'live',
    portrait: [
      _Layer(screen: 'live', theme: 'light', width: 0.64, x: 0.50, y: 0.0,
          behind: true),
      _Layer(screen: 'live', theme: 'dark',  width: 0.80, x: 0.015, y: 0.05),
    ],
    landscape: [
      _Layer(screen: 'live', theme: 'light', width: 0.58, x: 0.55, y: 0.0,
          behind: true),
      _Layer(screen: 'live', theme: 'dark',  width: 0.76, x: 0.005, y: 0.04),
    ],
    headlineDe: ['Kopfrechnen kannst', 'du dir sparen'],
    sublineDe:  'Der Weg zum Finish steht bei jedem Rest bereit',
    headlineEn: ['Leave the mental', 'arithmetic to us'],
    sublineEn:  'The route to the finish is ready at every score',
  ),
  _Image(
    name: 'summary',
    portrait: [
      _Layer(screen: 'summary', theme: 'dark',  width: 0.64, x: -0.14, y: 0.0,
          behind: true),
      _Layer(screen: 'summary', theme: 'light', width: 0.80, x: 0.205, y: 0.05),
    ],
    landscape: [
      _Layer(screen: 'summary', theme: 'dark',  width: 0.58, x: -0.13, y: 0.0,
          behind: true),
      _Layer(screen: 'summary', theme: 'light', width: 0.76, x: 0.219, y: 0.04),
    ],
    headlineDe: ['Jeder Wurf zählt', 'für deine Statistik'],
    sublineDe:  'Average, höchste Aufnahme, Checkout-Quote, Busts',
    headlineEn: ['Every dart counts', 'towards your stats'],
    sublineEn:  'Average, high score, checkout rate, busts',
  ),
];

/// Where the raw screenshots are read from.
const _kRawRoot = 'store_assets/screenshots/raw';

/// Where the composed pictures are written to.
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
      for (var i = 0; i < _kImages.length; i++) {
        final image  = _kImages[i];
        final layers = landscape ? image.landscape : image.portrait;

        final shots = <String, ({({int width, int height}) size, String data})>{};
        var missing = false;
        for (final layer in layers) {
          final key = '${layer.theme}/${layer.screen}';
          if (shots.containsKey(key)) continue;
          final raw = File('$_kRawRoot/$device/${layer.theme}/$language/'
              '${layer.screen}.png');
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
            '${i + 1}_${image.name}.png');
        await out.parent.create(recursive: true);
        await _render(
          out:      out,
          canvas:   canvas,
          layers:   layers,
          shots:    shots,
          headline: language == 'de' ? image.headlineDe : image.headlineEn,
          subline:  language == 'de' ? image.sublineDe  : image.sublineEn,
        );
        written++;
        stdout.writeln('${out.path}  (${canvas.slot})');
      }
    }
  }

  stdout.writeln('\n$written pictures written to $_kStoreRoot/.');
}

/// Renders one store picture.
Future<void> _render({
  required File out,
  required ({int width, int height, String slot}) canvas,
  required List<_Layer> layers,
  required Map<String, ({({int width, int height}) size, String data})> shots,
  required List<String> headline,
  required String subline,
}) async {
  final svg = _svg(
    canvas:   canvas,
    layers:   layers,
    shots:    shots,
    headline: headline,
    subline:  subline,
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

/// Builds the SVG for one picture.
String _svg({
  required ({int width, int height, String slot}) canvas,
  required List<_Layer> layers,
  required Map<String, ({({int width, int height}) size, String data})> shots,
  required List<String> headline,
  required String subline,
}) {
  final w = canvas.width.toDouble();
  final h = canvas.height.toDouble();
  final landscape = w > h;

  // ── Text block ──
  final headlineSize = min(w, h) * (landscape ? 0.052 : 0.055);
  final sublineSize  = headlineSize * 0.44;
  final lineHeight   = headlineSize * 1.2;
  final textTop      = h * (landscape ? 0.06 : 0.065);
  // Measured from the last headline baseline: its descender, a gap, and the
  // subline's own ascender. Anything less and the two lines touch.
  final sublineY     = textTop +
      lineHeight * headline.length +
      headlineSize * 0.67 +
      sublineSize * 0.75;
  final deviceTop    = sublineY + h * (landscape ? 0.05 : 0.04);

  final text = [
    for (var i = 0; i < headline.length; i++)
      '<text x="${_n(w / 2)}" y="${_n(textTop + lineHeight * (i + 1))}" '
          'text-anchor="middle" class="headline">${_escape(headline[i])}</text>',
    '<text x="${_n(w / 2)}" y="${_n(sublineY)}" '
        'text-anchor="middle" class="subline">${_escape(subline)}</text>',
  ].join('\n  ');

  // ── Device frames ──
  final clips  = StringBuffer();
  final frames = StringBuffer();

  for (var i = 0; i < layers.length; i++) {
    final layer = layers[i];
    final shot  = shots['${layer.theme}/${layer.screen}']!;

    final frameW = w * layer.width;
    final frameX = w * layer.x;
    final frameY = deviceTop + h * layer.y;

    // The bezel is a share of the frame, so it stays a bezel rather than
    // becoming a hairline on a small canvas and a slab on a large one.
    final bezel   = frameW * 0.018;
    final screenW = frameW - bezel * 2;
    final screenH = screenW * shot.size.height / shot.size.width;
    final frameH  = screenH + bezel * 2;
    final screenX = frameX + bezel;
    final screenY = frameY + bezel;

    final frameRadius  = frameW * 0.055;
    final screenRadius = frameRadius - bezel * 0.6;

    clips.writeln('''
    <clipPath id="screen$i">
      <rect x="${_n(screenX)}" y="${_n(screenY)}"
            width="${_n(screenW)}" height="${_n(screenH)}"
            rx="${_n(screenRadius)}" ry="${_n(screenRadius)}"/>
    </clipPath>''');

    frames.writeln('''
  <rect x="${_n(frameX)}" y="${_n(frameY)}"
        width="${_n(frameW)}" height="${_n(frameH)}"
        rx="${_n(frameRadius)}" ry="${_n(frameRadius)}"
        fill="#08080A" stroke="${layer.behind ? '#2E2E31' : '#4A4A4D'}"
        stroke-width="${_n(bezel * 0.24)}"/>
  <image x="${_n(screenX)}" y="${_n(screenY)}"
         width="${_n(screenW)}" height="${_n(screenH)}"
         clip-path="url(#screen$i)"
         xlink:href="data:image/png;base64,${shot.data}"/>''');

    // A frame standing behind another one is pushed back with a scrim rather
    // than with a blur: it stays readable as the same app in the other theme,
    // which is the whole point of showing it, while the eye still lands on the
    // frame in front.
    if (layer.behind) {
      frames.writeln('''
  <rect x="${_n(frameX)}" y="${_n(frameY)}"
        width="${_n(frameW)}" height="${_n(frameH)}"
        rx="${_n(frameRadius)}" ry="${_n(frameRadius)}"
        fill="#0A0A0B" fill-opacity="0.34"/>''');
    }
  }

  // The glow sits behind the frames and is centred on where they start, so the
  // background is brightest where the picture is busiest.
  final glowY = (deviceTop + h * 0.12) / h;

  return '''
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="${canvas.width}" height="${canvas.height}"
     viewBox="0 0 ${canvas.width} ${canvas.height}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0"    stop-color="#2C1416"/>
      <stop offset="0.55" stop-color="#150C0D"/>
      <stop offset="1"    stop-color="#09090A"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="${_n(glowY)}" r="0.72">
      <stop offset="0" stop-color="#B71C1C" stop-opacity="0.40"/>
      <stop offset="1" stop-color="#B71C1C" stop-opacity="0"/>
    </radialGradient>
$clips  </defs>
  <style>
    .headline, .subline {
      font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
    }
    .headline {
      font-weight: 700;
      font-size: ${_n(headlineSize)}px;
      fill: #FFFFFF;
      letter-spacing: ${_n(headlineSize * -0.018)}px;
    }
    .subline {
      font-weight: 400;
      font-size: ${_n(sublineSize)}px;
      fill: #E4C9C9;
    }
  </style>

  <rect width="100%" height="100%" fill="url(#bg)"/>
  <rect width="100%" height="100%" fill="url(#glow)"/>

  $text
$frames</svg>
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
