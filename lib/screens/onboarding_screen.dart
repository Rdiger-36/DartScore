import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/players_provider.dart';
import '../widgets/dartboard_icon.dart';
import '../utils/layout.dart';

/// First-launch walkthrough that creates the primary player (name and favorite
/// double) before entering the app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  String? _selectedDouble;
  bool _saving = false;
  bool _showDoubleError = false;

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

  /// Creates the primary player from the entered name and double, then finishes
  /// onboarding.
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    if (_selectedDouble == null) {
      setState(() => _showDoubleError = true);
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<PlayersProvider>();
    final player = await provider.addPlayer(name, isPrimary: true);
    await provider.updatePlayer(
        player.copyWith(favoriteDoubles: _selectedDouble));
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
              constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
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
                    textInputAction: TextInputAction.done,
                    maxLength: 12,
                    decoration: InputDecoration(
                      labelText: l.yourName,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  ),
                  const SizedBox(height: 24),

                  // ── Favorite double (required) ────────────────────────────
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDouble,
                    decoration: InputDecoration(
                      labelText: l.favDoublesTitle,
                      border: const OutlineInputBorder(),
                      errorText: _showDoubleError ? l.favDoublesRequired : null,
                    ),
                    hint: Text(l.favDoublesTitle),
                    items: _allDoubles
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (val) => setState(() {
                      _selectedDouble = val;
                      _showDoubleError = false;
                    }),
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
