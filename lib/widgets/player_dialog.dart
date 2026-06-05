import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/layout.dart';

class PlayerDialog extends StatefulWidget {
  final String? initialName;
  final String? initialDouble;
  final void Function(String name, String favoriteDouble) onSave;

  const PlayerDialog({
    super.key,
    this.initialName,
    this.initialDouble,
    required this.onSave,
  });

  @override
  State<PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends State<PlayerDialog> {
  late final TextEditingController _nameCtrl;
  String? _selectedDouble;
  bool _showDoubleError = false;

  static const _allDoubles = [
    'D1','D2','D3','D4','D5','D6','D7','D8','D9','D10',
    'D11','D12','D13','D14','D15','D16','D17','D18','D19','D20',
    'Bull',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _selectedDouble = widget.initialDouble;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final canSave = _nameCtrl.text.trim().isNotEmpty && _selectedDouble != null;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
      child: AlertDialog(
        title: Text(
            widget.initialName == null ? l.addPlayerTitle : l.editPlayerTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l.nameLabel,
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Text(
                l.favDoublesTitle,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _showDoubleError
                      ? theme.colorScheme.error
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _allDoubles.map((d) {
                  return FilterChip(
                    label: Text(d),
                    selected: _selectedDouble == d,
                    onSelected: (_) => setState(() {
                      _selectedDouble = d;
                      _showDoubleError = false;
                    }),
                  );
                }).toList(),
              ),
              if (_showDoubleError) ...[
                const SizedBox(height: 6),
                Text(
                  l.favDoublesRequired,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: canSave ? _save : _onSaveAttempt,
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  void _onSaveAttempt() {
    setState(() => _showDoubleError = _selectedDouble == null);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _selectedDouble == null) {
      setState(() => _showDoubleError = _selectedDouble == null);
      return;
    }
    widget.onSave(name, _selectedDouble!);
    Navigator.pop(context);
  }
}
