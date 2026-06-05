import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/layout.dart';
import 'game_mode_info_screen.dart';
import 'game_setup_screen.dart';
import 'cricket_setup_screen.dart';

class GameModeSelectionScreen extends StatelessWidget {
  const GameModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l.selectGameMode)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ModeCard(
                    mode: GameModeOption.x01,
                    name: l.modeX01Name,
                    tagline: l.modeX01Tagline,
                    available: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GameSetupScreen()),
                    ),
                    onInfo: () => _openInfo(context, GameModeOption.x01),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    mode: GameModeOption.cricket,
                    name: l.modeCricketName,
                    tagline: l.modeCricketTagline,
                    available: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CricketSetupScreen()),
                    ),
                    onInfo: () => _openInfo(context, GameModeOption.cricket),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    mode: GameModeOption.shanghai,
                    name: l.modeShanghaiName,
                    tagline: l.modeShanghaiTagline,
                    available: false,
                    onInfo: () => _openInfo(context, GameModeOption.shanghai),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    mode: GameModeOption.aroundTheClock,
                    name: l.modeAroundClockName,
                    tagline: l.modeAroundClockTagline,
                    available: false,
                    onInfo: () => _openInfo(context, GameModeOption.aroundTheClock),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openInfo(BuildContext context, GameModeOption mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameModeInfoScreen(mode: mode),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final GameModeOption mode;
  final String name;
  final String tagline;
  final bool available;
  final VoidCallback? onTap;
  final VoidCallback onInfo;

  const _ModeCard({
    required this.mode,
    required this.name,
    required this.tagline,
    required this.available,
    required this.onInfo,
    this.onTap,
  });

  IconData get _icon {
    switch (mode) {
      case GameModeOption.x01:
        return Icons.filter_none_rounded;
      case GameModeOption.cricket:
        return Icons.sports_cricket_rounded;
      case GameModeOption.shanghai:
        return Icons.layers_rounded;
      case GameModeOption.aroundTheClock:
        return Icons.watch_later_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;

    final contentColor = available
        ? cs.onSurface
        : cs.onSurface.withValues(alpha: 0.45);
    final iconColor = available ? cs.primary : cs.onSurface.withValues(alpha: 0.35);

    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: available ? cs.outlineVariant : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Icon(_icon, size: 36, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: contentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: contentColor.withValues(alpha: 0.8),
                      ),
                    ),
                    if (!available) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l.comingSoon,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onInfo,
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: available ? cs.primary : cs.onSurface.withValues(alpha: 0.4),
                ),
                tooltip: l.modeInfoTitle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
