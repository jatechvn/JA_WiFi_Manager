// lib/modules/ui/dialogs.dart
// Dialog components for Whitelist management and user guidance

import 'package:flutter/material.dart';
import '../logic.dart';
import '../i18n.dart';
import '../utils.dart';
import 'styles.dart';

/// Dialog to add a new device to the Whitelist
class AddDeviceDialog extends StatefulWidget {
  final WifiGuardLogic logic;
  const AddDeviceDialog({super.key, required this.logic});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _macController = TextEditingController();
  final _nicknameController = TextEditingController();
  String _errorText = '';

  @override
  void dispose() {
    _macController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _submit() async {
    setState(() => _errorText = '');
    final s = context.strings;
    if (!_formKey.currentState!.validate()) return;

    final mac = normalizeMacAddress(_macController.text);
    if (!isValidMacAddress(mac)) {
      setState(() => _errorText = s.errInvalidMac);
      return;
    }

    final success = await widget.logic
        .addWhitelistDevice(mac, _nicknameController.text.trim());
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorText = s.errMacExists);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;

    return Dialog(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.dlgAddTitle,
                  style: Theme.of(context).dialogTheme.titleTextStyle),
              const SizedBox(height: 20),
              // MAC Field
              Text(s.labelMac,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _macController,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontFamily: 'Cascadia Code'),
                decoration: InputDecoration(
                  hintText: s.hintMac,
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? s.errFillRequired
                    : null,
              ),
              const SizedBox(height: 16),
              // Nickname Field
              Text(s.labelNickname,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nicknameController,
                style: TextStyle(color: c.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: s.hintNickname,
                ),
              ),
              if (_errorText.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  _errorText,
                  style: TextStyle(
                      color: c.statusRemoved,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(s.btnCancel),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(s.btnSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog to edit device nickname
class EditNicknameDialog extends StatefulWidget {
  final String currentMac;
  final String currentNickname;
  final WifiGuardLogic logic;

  const EditNicknameDialog({
    super.key,
    required this.currentMac,
    required this.currentNickname,
    required this.logic,
  });

  @override
  State<EditNicknameDialog> createState() => _EditNicknameDialogState();
}

class _EditNicknameDialogState extends State<EditNicknameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.currentNickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.logic
        .editDeviceNickname(widget.currentMac, _nicknameController.text.trim());
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;

    return Dialog(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.dlgEditTitle,
                  style: Theme.of(context).dialogTheme.titleTextStyle),
              const SizedBox(height: 20),
              Text(s.labelMac,
                  style: TextStyle(fontSize: 11, color: c.textMuted)),
              const SizedBox(height: 2),
              Text(widget.currentMac,
                  style: TextStyle(
                      fontFamily: 'Cascadia Code',
                      fontSize: 13,
                      color: c.linkAccent)),
              const SizedBox(height: 16),
              Text(s.labelNickname,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nicknameController,
                autofocus: true,
                style: TextStyle(color: c.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: s.hintNickname,
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? s.errFillRequired
                    : null,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(s.btnCancel),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(s.btnSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog to confirm removal of whitelisted MAC
class DeleteDeviceDialog extends StatelessWidget {
  final WhitelistEntry entry;
  const DeleteDeviceDialog({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;

    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.dlgDeleteTitle,
                style: Theme.of(context).dialogTheme.titleTextStyle),
            const SizedBox(height: 16),
            Text(
              s.dlgDeleteConfirm(
                  entry.nickname.isNotEmpty ? entry.nickname : entry.mac),
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              entry.mac,
              style: TextStyle(
                  fontFamily: 'Cascadia Code',
                  fontSize: 12,
                  color: c.textMuted),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(s.btnCancel),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.statusRemoved.withValues(alpha: 0.12),
                    foregroundColor: c.statusRemoved,
                    side: BorderSide(
                        color: c.statusRemoved.withValues(alpha: 0.35)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(s.btnDelete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to show import logs summary
class ImportResultsDialog extends StatelessWidget {
  final Map<String, int> result;
  const ImportResultsDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;

    return Dialog(
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.dlgImportTitle,
                style: Theme.of(context).dialogTheme.titleTextStyle),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.bgTertiary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.borderDefault),
              ),
              child: Text(
                s.importSummary(
                  result['success'] ?? 0,
                  result['skipped'] ?? 0,
                  result['failed'] ?? 0,
                ),
                style: TextStyle(
                  fontFamily: 'Cascadia Code',
                  fontSize: 13,
                  color: c.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.btnClose),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
