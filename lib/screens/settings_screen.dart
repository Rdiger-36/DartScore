import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: contentPadding(context, top: 12, bottom: 28, innerH: 14),
        children: const [
          _ThemeSection(),
          SizedBox(height: 20),
          _LanguageSection(),
        ],
      ),
    );
  }
}

// ── Theme ─────────────────────────────────────────────────────────────────────

class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return _Card(
      title: l.appearance,
      icon: Icons.palette_outlined,
      child: Column(
        children: [
          _ThemeTile(
            label: l.system,
            subtitle: l.systemDesc,
            icon: Icons.brightness_auto_rounded,
            selected: tp.mode == ThemeMode.system,
            onTap: () => tp.setMode(ThemeMode.system),
            cs: cs,
          ),
          const Divider(height: 1),
          _ThemeTile(
            label: l.light,
            subtitle: l.lightDesc,
            icon: Icons.light_mode_rounded,
            selected: tp.mode == ThemeMode.light,
            onTap: () => tp.setMode(ThemeMode.light),
            cs: cs,
          ),
          const Divider(height: 1),
          _ThemeTile(
            label: l.dark,
            subtitle: l.darkDesc,
            icon: Icons.dark_mode_rounded,
            selected: tp.mode == ThemeMode.dark,
            onTap: () => tp.setMode(ThemeMode.dark),
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _ThemeTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
      title: Text(label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? cs.primary : null,
          )),
      subtitle: Text(subtitle),
      trailing:
          selected ? Icon(Icons.check_circle_rounded, color: cs.primary) : null,
      onTap: onTap,
    );
  }
}

// ── Language ──────────────────────────────────────────────────────────────────

class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LanguageProvider>();
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return _Card(
      title: l.language,
      icon: Icons.language_rounded,
      child: Column(
        children: [
          _LangTile(
            label: l.system,
            subtitle: l.systemDesc,
            flag: '🌐',
            selected: lp.languageCode == null,
            onTap: () => lp.setLanguage(null),
            cs: cs,
          ),
          const Divider(height: 1),
          _LangTile(
            label: 'English',
            subtitle: 'English',
            flag: '🇬🇧',
            selected: lp.languageCode == 'en',
            onTap: () => lp.setLanguage('en'),
            cs: cs,
          ),
          const Divider(height: 1),
          _LangTile(
            label: 'Deutsch',
            subtitle: 'German',
            flag: '🇩🇪',
            selected: lp.languageCode == 'de',
            onTap: () => lp.setLanguage('de'),
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final String flag;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _LangTile({
    required this.label,
    required this.subtitle,
    required this.flag,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? cs.primary : null,
          )),
      subtitle: Text(subtitle,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      trailing:
          selected ? Icon(Icons.check_circle_rounded, color: cs.primary) : null,
      onTap: onTap,
    );
  }
}

// ── Card wrapper ──────────────────────────────────────────────────────────────

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
