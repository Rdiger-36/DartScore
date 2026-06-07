import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../utils/layout.dart';
import '../widgets/dartboard_icon.dart';

const _projectUrl = 'https://rdiger-36.github.io/Rdiger-36/';

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
