import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../utils/layout.dart';
import '../widgets/dartboard_icon.dart';

const _projectUrl = 'https://rdiger-36.github.io/Rdiger-36/';

const _licenseUrl = 'https://www.gnu.org/licenses/gpl-3.0.html';

const _gplNoticeText = '''
DartScore
Copyright (C) 2026 Niklas Ratka

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. The full license text is included in the
repository (LICENSE) and available at gnu.org/licenses.
''';

class _LicenseTextScreen extends StatelessWidget {
  const _LicenseTextScreen();

  Future<void> _openFullLicense(BuildContext context) async {
    final ok = await launchUrl(Uri.parse(_licenseUrl), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.linkOpenError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.license)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.appName,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(l.licenseDesc,
              style: Theme.of(context).textTheme.bodySmall),
          const Divider(height: 24),
          Text(_gplNoticeText, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openFullLicense(context),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l.licenseFullText),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }

  Future<void> _openLink(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.linkOpenError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final info = _packageInfo;

    return Scaffold(
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: ListView(
        padding: contentPadding(context, top: 12, bottom: 28, innerH: 14),
        children: [
          Column(
            children: [
              const DartboardIcon(size: 72),
              const SizedBox(height: 12),
              Text(l.appName,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
              const SizedBox(height: 4),
              Text(
                info == null
                    ? ''
                    : '${l.version} ${info.version} (${info.buildNumber})',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Card(
            title: l.developer,
            icon: Icons.code_rounded,
            child: const ListTile(
              leading: Icon(Icons.person_rounded),
              title: Text('Niklas Ratka'),
            ),
          ),
          const SizedBox(height: 20),
          _Card(
            title: l.support,
            icon: Icons.help_outline_rounded,
            child: ListTile(
              leading: const Icon(Icons.support_agent_rounded),
              title: Text(l.support),
              subtitle: Text(l.supportDesc),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _openLink(Uri.parse(_projectUrl)),
            ),
          ),
          const SizedBox(height: 20),
          _Card(
            title: l.license,
            icon: Icons.gavel_rounded,
            child: ListTile(
              leading: const Icon(Icons.balance_outlined),
              title: Text(l.license),
              subtitle: Text(l.licenseDesc),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _LicenseTextScreen()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Card(
            title: l.openSourceLicenses,
            icon: Icons.inventory_2_outlined,
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l.openSourceLicenses),
              subtitle: Text(l.openSourceLicensesDesc),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l.appName,
                applicationVersion: info?.version,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Card({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
        ),
        Card(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
        ),
      ],
    );
  }
}
