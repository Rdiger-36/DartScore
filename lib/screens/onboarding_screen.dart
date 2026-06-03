import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/players_provider.dart';
import '../widgets/dartboard_icon.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  String? _selectedDouble;
  bool _saving = false;

  static const _allDoubles = [
    'D1','D2','D3','D4','D5','D6','D7','D8','D9','D10',
    'D11','D12','D13','D14','D15','D16','D17','D18','D19','D20',
    'Bull',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final provider = context.read<PlayersProvider>();
    final player = await provider.addPlayer(name, isPrimary: true);
    if (_selectedDouble != null) {
      await provider.updatePlayer(
          player.copyWith(favoriteDoubles: _selectedDouble));
    }
    // PlayersProvider now has a primary player → _AppGate will rebuild to HomeScreen.
  }

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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Icon + Title ────────────────────────────────────────
                  const DartboardIcon(size: 100),
                  const SizedBox(height: 20),
                  Text(
                    l.welcomeTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.welcomeSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Name ────────────────────────────────────────────────
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l.yourName,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 24),

                  // ── Favorite double (optional) ───────────────────────────
                  Text(
                    l.favDoublesTitle,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _allDoubles.map((d) {
                      final sel = _selectedDouble == d;
                      return FilterChip(
                        label: Text(d),
                        selected: sel,
                        onSelected: (_) =>
                            setState(() => _selectedDouble = sel ? null : d),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 36),

                  // ── CTA ──────────────────────────────────────────────────
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(l.letsGo),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
