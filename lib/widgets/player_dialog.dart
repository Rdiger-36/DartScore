import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/layout.dart';

class PlayerDialog extends StatefulWidget {
  final String? initialName;
  final String? initialDouble;
  final bool isPrimary;
  final List<String> existingNames;
  final void Function(String name, String favoriteDouble) onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onSetPrimary;

  const PlayerDialog({
    super.key,
    this.initialName,
    this.initialDouble,
    this.isPrimary = false,
    this.existingNames = const [],
    required this.onSave,
    this.onDelete,
    this.onSetPrimary,
  });

  @override
  State<PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends State<PlayerDialog> {
  late final TextEditingController _nameCtrl;
  String? _selectedDouble;
  bool _showDoubleError = false;
  bool _showNameError = false;
  late bool _isPrimary;

  static const _allDoubles = [
    'D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7', 'D8', 'D9', 'D10',
    'D11', 'D12', 'D13', 'D14', 'D15', 'D16', 'D17', 'D18', 'D19', 'D20',
    'Bull',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _selectedDouble = widget.initialDouble;
    _isPrimary = widget.isPrimary;
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
    final cs = theme.colorScheme;
    final canSave = _nameCtrl.text.trim().isNotEmpty && _selectedDouble != null && !_showNameError;
    final isEditing = widget.initialName != null;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title row with X close button ─────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? l.editPlayerTitle : l.addPlayerTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l.cancel,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Scrollable content ────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _nameCtrl,
                          autofocus: !isEditing,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: l.nameLabel,
                            border: const OutlineInputBorder(),
                            errorText: _showNameError ? l.nameAlreadyExists : null,
                          ),
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() => _showNameError = false),
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedDouble,
                          decoration: InputDecoration(
                            labelText: l.favDoublesTitle,
                            border: const OutlineInputBorder(),
                            errorText:
                                _showDoubleError ? l.favDoublesRequired : null,
                          ),
                          hint: Text(l.favDoublesTitle),
                          items: _allDoubles
                              .map((d) =>
                                  DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (val) => setState(() {
                            _selectedDouble = val;
                            _showDoubleError = false;
                          }),
                        ),
                        if (isEditing && widget.onSetPrimary != null) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _isPrimary,
                            onChanged: widget.isPrimary
                                ? null
                                : (val) =>
                                    setState(() => _isPrimary = val),
                            secondary: Icon(
                              Icons.star_rounded,
                              color: _isPrimary
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                            ),
                            title: Text(
                              _isPrimary
                                  ? l.alreadyMainProfile
                                  : l.setAsMainProfile,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Bottom action row ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    if (widget.onDelete != null)
                      IconButton.outlined(
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        tooltip: l.delete,
                        style: IconButton.styleFrom(
                          side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDelete!();
                        },
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: Text(l.save),
                      onPressed: canSave ? _save : _onSaveAttempt,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    if (widget.existingNames.contains(name.toLowerCase())) {
      setState(() => _showNameError = true);
      return;
    }
    widget.onSave(name, _selectedDouble!);
    if (_isPrimary && !widget.isPrimary && widget.onSetPrimary != null) {
      widget.onSetPrimary!();
    }
    Navigator.pop(context);
  }
}
