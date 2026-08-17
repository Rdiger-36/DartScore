import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Turns the raw screenshots into the pictures the two store listings show:
/// the screen in a device frame, on a background, under a headline.
///
/// Run it after `tool/store_screenshots.sh` has filled
/// `store_assets/screenshots/raw/`:
///
///     dart run tool/compose_store_screenshots.dart
///     dart run tool/compose_store_screenshots.dart --theme=light
///
/// It writes `store_assets/screenshots/store/<device>/<language>/`, numbered in
/// the order the pictures should be uploaded in.
///
/// Composing goes through SVG and `rsvg-convert` (`brew install librsvg`)
/// rather than an image package, because the whole job is a gradient, a rounded
/// rectangle, a bitmap and two lines of text. A renderer that already does all
/// four is a smaller dependency than a pixel loop that has to learn them.

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

/// The screens, in upload order, with the headline each one carries.
///
/// The lines are split by hand because SVG has no line breaking of its own, and
/// a headline that wraps where the renderer feels like it reads worse than one
/// broken where the sentence does.
const _kScreens = <({String name, List<String> de, List<String> en})>[
  (
    name: 'modes',
    de: ['Vier Spielmodi,', 'ein Zähler'],
    en: ['Four game modes,', 'one scorer'],
  ),
  (
    name: 'live',
    de: ['Der Finish-Weg', 'steht schon da'],
    en: ['The checkout route', 'is already there'],
  ),
  (
    name: 'summary',
    de: ['Jedes Spiel', 'komplett ausgewertet'],
    en: ['Every game', 'fully broken down'],
  ),
];

/// Where the raw screenshots are read from.
const _kRawRoot = 'store_assets/screenshots/raw';

/// Where the composed pictures are written to.
const _kStoreRoot = 'store_assets/screenshots/store';

Future<void> main(List<String> args) async {
  final theme = args
          .firstWhere((a) => a.startsWith('--theme='), orElse: () => '')
          .split('=')
          .last
          .trim();
  final source = theme.isEmpty ? 'dark' : theme;

  if (!await _hasRsvg()) {
    stderr.writeln('rsvg-convert is missing. Install it with: brew install librsvg');
    exit(1);
  }

  var written = 0;
  for (final device in _kCanvases.keys) {
    for (final language in const ['de', 'en']) {
      for (var i = 0; i < _kScreens.length; i++) {
        final screen = _kScreens[i];
        final raw = File('$_kRawRoot/$device/$source/$language/${screen.name}.png');
        if (!raw.existsSync()) {
          stderr.writeln('missing, skipped: ${raw.path}');
          continue;
        }

        final out = File('$_kStoreRoot/$device/$language/'
            '${i + 1}_${screen.name}.png');
        await out.parent.create(recursive: true);
        await _compose(
          raw:      raw,
          out:      out,
          canvas:   _kCanvases[device]!,
          headline: language == 'de' ? screen.de : screen.en,
        );
        written++;
        stdout.writeln('${out.path}  (${_kCanvases[device]!.slot})');
      }
    }
  }

  stdout.writeln('\n$written pictures written to $_kStoreRoot/.');
}

/// Renders one store picture from the raw screenshot [raw].
Future<void> _compose({
  required File raw,
  required File out,
  required ({int width, int height, String slot}) canvas,
  required List<String> headline,
}) async {
  final bytes = await raw.readAsBytes();
  final source = _pngSize(bytes);
  final svg = _svg(
    canvas:   canvas,
    shot:     source,
    shotData: base64Encode(bytes),
    headline: headline,
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
    throw StateError('rsvg-convert failed on ${raw.path}: ${result.stderr}');
  }
}

/// Builds the SVG for one picture.
///
/// The layout is proportional to the canvas throughout, so the same code lays
/// out a tall phone and a wide tablet: the headline takes a share of the height
/// and the framed screen takes whatever is left, scaled to fit both ways.
String _svg({
  required ({int width, int height, String slot}) canvas,
  required ({int width, int height}) shot,
  required String shotData,
  required List<String> headline,
}) {
  final w = canvas.width.toDouble();
  final h = canvas.height.toDouble();
  final landscape = w > h;

  final margin      = w * (landscape ? 0.045 : 0.06);
  final fontSize    = min(w, h) * (landscape ? 0.052 : 0.055);
  final lineHeight  = fontSize * 1.22;
  final headlineTop = h * (landscape ? 0.07 : 0.075);
  final deviceTop   = headlineTop + lineHeight * (headline.length - 0.35) +
      h * (landscape ? 0.035 : 0.03);

  // The bezel is a share of the framed width, so it stays a bezel rather than
  // becoming a border on a small canvas and a slab on a large one.
  const bezelRatio = 0.018;
  final availableW = w - margin * 2;
  final availableH = h - deviceTop - margin;
  final scale = min(
    availableW / (shot.width * (1 + bezelRatio * 2)),
    availableH / (shot.height + shot.width * bezelRatio * 2),
  );

  final screenW = shot.width * scale;
  final screenH = shot.height * scale;
  final bezel   = shot.width * scale * bezelRatio;
  final frameW  = screenW + bezel * 2;
  final frameH  = screenH + bezel * 2;
  final frameX  = (w - frameW) / 2;
  final frameY  = deviceTop;
  final screenX = frameX + bezel;
  final screenY = frameY + bezel;

  // The corner of a phone, carried over to the screen inside it so the picture
  // does not show a rounded frame around a square panel.
  final frameRadius  = frameW * 0.055;
  final screenRadius = frameRadius - bezel * 0.6;

  final lines = [
    for (var i = 0; i < headline.length; i++)
      '<text x="${_n(w / 2)}" y="${_n(headlineTop + lineHeight * (i + 1))}" '
          'text-anchor="middle" class="headline">${_escape(headline[i])}</text>',
  ].join('\n  ');

  return '''
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="${canvas.width}" height="${canvas.height}"
     viewBox="0 0 ${canvas.width} ${canvas.height}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0"   stop-color="#2A1315"/>
      <stop offset="0.55" stop-color="#150C0D"/>
      <stop offset="1"   stop-color="#0A0A0B"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="${_n(frameY / h)}" r="0.7">
      <stop offset="0" stop-color="#B71C1C" stop-opacity="0.42"/>
      <stop offset="1" stop-color="#B71C1C" stop-opacity="0"/>
    </radialGradient>
    <clipPath id="screen">
      <rect x="${_n(screenX)}" y="${_n(screenY)}"
            width="${_n(screenW)}" height="${_n(screenH)}"
            rx="${_n(screenRadius)}" ry="${_n(screenRadius)}"/>
    </clipPath>
  </defs>
  <style>
    .headline {
      font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
      font-weight: 700;
      font-size: ${_n(fontSize)}px;
      fill: #FFFFFF;
      letter-spacing: ${_n(fontSize * -0.015)}px;
    }
  </style>

  <rect width="100%" height="100%" fill="url(#bg)"/>
  <rect width="100%" height="100%" fill="url(#glow)"/>

  $lines

  <rect x="${_n(frameX)}" y="${_n(frameY)}"
        width="${_n(frameW)}" height="${_n(frameH)}"
        rx="${_n(frameRadius)}" ry="${_n(frameRadius)}"
        fill="#0A0A0B" stroke="#454547" stroke-width="${_n(bezel * 0.22)}"/>
  <image x="${_n(screenX)}" y="${_n(screenY)}"
         width="${_n(screenW)}" height="${_n(screenH)}"
         clip-path="url(#screen)"
         xlink:href="data:image/png;base64,$shotData"/>
</svg>
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
