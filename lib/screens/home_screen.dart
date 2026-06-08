import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../widgets/dartboard_icon.dart';
import 'players_screen.dart';
import 'game_mode_selection_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import '../utils/dev_build_info.dart';
import '../utils/layout.dart';
import '../utils/remote_killswitch.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DartboardIcon(size: 110),
                  const SizedBox(height: 16),
                  Text(
                    l.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _HomeButton(
                    icon: Icons.play_arrow_rounded,
                    label: l.newGame,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GameModeSelectionScreen()),
                    ),
                    primary: true,
                  ),
                  const SizedBox(height: 14),
                  _HomeButton(
                    icon: Icons.people_outlined,
                    label: l.managePlayers,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PlayersScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HomeButton(
                    icon: Icons.history_rounded,
                    label: l.gameHistory,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HomeButton(
                    icon: Icons.settings_outlined,
                    label: l.settings,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  if (devBuildInfo != null) ...[
                    const SizedBox(height: 24),
                    const _BetaBadge(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small unobtrusive notice shown on the home screen while a dev/test build
/// is active (see [DevBuildInfo]), so testers know they're running a beta
/// and roughly how long it remains valid. Prefers the remote expiry — which
/// the developer can extend without shipping a new build — and falls back to
/// the bundled date.
class _BetaBadge extends StatelessWidget {
  const _BetaBadge();

  @override
  Widget build(BuildContext context) {
    final devBuild = devBuildInfo;
    if (devBuild == null) return const SizedBox.shrink();

    // _AppGate already blocks access for "active: false" or expired remote
    // status before this screen can ever be reached, so reaching here means
    // the remote expiry (when known) is the relevant one to display.
    final expiry = remoteKillswitchStatus?.expiry ?? devBuild.expiry;
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat('dd.MM.yyyy').format(expiry);

    return Text(
      context.l10n.betaBadgeValidUntil(date),
      textAlign: TextAlign.center,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: cs.onSurfaceVariant),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _HomeButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (primary) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 28),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          textStyle: theme.textTheme.titleLarge,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        textStyle: theme.textTheme.titleMedium,
      ),
    );
  }
}
