// lib/modules/ui/hotspot_tab.dart
// Hotspot tab: Windows Mobile Hotspot status and Wi-Fi configuration form with Bento Glassmorphic UI.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic.dart';
import '../i18n.dart';
import 'styles.dart';
import 'bento_widgets.dart';

class HotspotTab extends StatefulWidget {
  final WifiGuardLogic logic;
  final void Function(String message, {bool isError}) onSnackbar;
  final ValueChanged<String> onNavigateToTab;

  const HotspotTab({
    super.key,
    required this.logic,
    required this.onSnackbar,
    required this.onNavigateToTab,
  });

  @override
  State<HotspotTab> createState() => _HotspotTabState();
}

class _HotspotTabState extends State<HotspotTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _maxClientsController = TextEditingController();
  String _selectedBand = 'Auto';
  bool _isToggling = false;
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _isFixingDhcp = false;
  bool _isFixingIcs = false;

  @override
  void initState() {
    super.initState();
    final config = widget.logic.hotspotConfig;
    if (config != null) {
      _ssidController.text = config.ssid;
      _passwordController.text = config.passphrase;
      _selectedBand = config.band;
      _maxClientsController.text = config.maxClients.toString();
    }
    widget.logic.addListener(_onLogicChange);
  }

  @override
  void dispose() {
    widget.logic.removeListener(_onLogicChange);
    _ssidController.dispose();
    _passwordController.dispose();
    _maxClientsController.dispose();
    super.dispose();
  }

  void _onLogicChange() {
    if (!mounted) return;
    final config = widget.logic.hotspotConfig;
    if (config != null) {
      if (_ssidController.text.isEmpty && config.ssid.isNotEmpty) {
        _ssidController.text = config.ssid;
      }
      if (_passwordController.text.isEmpty && config.passphrase.isNotEmpty) {
        _passwordController.text = config.passphrase;
      }
      if (_maxClientsController.text.isEmpty) {
        _maxClientsController.text = config.maxClients.toString();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;
    final config = widget.logic.hotspotConfig;

    final titleConfig = s.hotspotConfigTitle;
    final labelSsid = s.hotspotSsidLabel;
    final labelPassphrase = s.hotspotPasswordLabel;
    final labelBand = s.hotspotBandLabel;
    final labelSave = s.hotspotSave;
    final msgUpdating = s.hotspotUpdating;
    final msgSuccess = s.hotspotUpdated;
    final msgError = s.hotspotUpdateFailed;
    final noteText = s.hotspotNote;
    final labelMaxClients = s.hotspotMaxClients;

    if (config == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: c.linkAccent),
            const SizedBox(height: 16),
            Text(
              s.hotspotLoading,
              style: TextStyle(color: c.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final isHotspotOn = config.state == 'Enabled';

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Hotspot Status Banner Bento Card
            BentoCard(
              colors: c,
              isFeatured: isHotspotOn,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Sóng Wi-Fi Icon Box
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isHotspotOn
                              ? c.accentEmerald.withValues(alpha: 0.15)
                              : c.subCardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isHotspotOn
                                ? c.accentEmerald.withValues(alpha: 0.4)
                                : c.borderDefault,
                          ),
                        ),
                        child: Icon(
                          Icons.wifi_tethering_rounded,
                          size: 20,
                          color: isHotspotOn ? c.accentEmerald : c.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Hotspot State & Name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    config.ssid.isNotEmpty
                                        ? config.ssid
                                        : s.hotspotDefaultName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PillBadge(
                                  label: isHotspotOn ? 'ONLINE' : 'STOPPED',
                                  color: isHotspotOn
                                      ? c.accentEmerald
                                      : c.accentRose,
                                  bg: (isHotspotOn
                                          ? c.accentEmerald
                                          : c.accentRose)
                                      .withValues(alpha: 0.12),
                                  border: (isHotspotOn
                                          ? c.accentEmerald
                                          : c.accentRose)
                                      .withValues(alpha: 0.3),
                                  showDot: true,
                                  fontSize: 9.5,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                ),
                                const SizedBox(width: 6),
                                PillBadge(
                                  label: _formatBandLabel(config.band),
                                  color: c.linkAccent,
                                  bg: c.linkAccent.withValues(alpha: 0.10),
                                  border: c.linkAccent.withValues(alpha: 0.25),
                                  fontSize: 9.5,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isHotspotOn
                                  ? s.hotspotBroadcasting
                                  : s.hotspotStoppedHint,
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    isHotspotOn ? c.textSecondary : c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Toggle Switch with Loading Indicator
                      _isToggling
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Transform.scale(
                              scale: 0.9,
                              child: Switch(
                                value: isHotspotOn,
                                activeThumbColor: c.statusActive,
                                onChanged: (val) async {
                                  setState(() => _isToggling = true);
                                  final ok =
                                      await widget.logic.setHotspotState(val);
                                  if (!mounted) return;
                                  setState(() => _isToggling = false);
                                  if (ok) {
                                    widget.onSnackbar(s.hotspotToggled);
                                  } else {
                                    widget.onSnackbar(
                                      s.hotspotToggleFailed,
                                      isError: true,
                                    );
                                  }
                                },
                              ),
                            ),
                    ],
                  ),
                  const Divider(height: 14),

                  // Quick Action Buttons Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Fix ICS button
                      OutlinedButton.icon(
                        onPressed: _isFixingIcs
                            ? null
                            : () async {
                                setState(() => _isFixingIcs = true);
                                widget.onSnackbar(s.hotspotIcsWorking);
                                final ok =
                                    await widget.logic.repairIcsService();
                                if (!mounted) return;
                                setState(() => _isFixingIcs = false);
                                if (ok) {
                                  widget.onSnackbar(s.hotspotIcsOk);
                                } else {
                                  widget.onSnackbar(
                                    s.hotspotIcsFailed,
                                    isError: true,
                                  );
                                }
                              },
                        icon: _isFixingIcs
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.build_circle_rounded,
                                size: 15, color: c.statusChanged),
                        label: Text(
                          s.hotspotFixIcs,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: c.statusChanged,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: c.statusChanged.withValues(alpha: 0.4),
                          ),
                          backgroundColor:
                              c.statusChanged.withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Fix DHCP button
                      OutlinedButton.icon(
                        onPressed: _isFixingDhcp
                            ? null
                            : () async {
                                setState(() => _isFixingDhcp = true);
                                widget.onSnackbar(s.hotspotDhcpWorking);
                                final ok = await widget.logic.fixHotspotDhcp();
                                if (!mounted) return;
                                setState(() => _isFixingDhcp = false);
                                if (ok) {
                                  widget.onSnackbar(s.hotspotDhcpOk);
                                } else {
                                  widget.onSnackbar(
                                    s.hotspotDhcpFailed,
                                    isError: true,
                                  );
                                }
                              },
                        icon: _isFixingDhcp
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.restart_alt_rounded,
                                size: 14, color: c.linkAccent),
                        label: Text(
                          s.hotspotFixDhcp,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: c.linkAccent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: c.linkAccent.withValues(alpha: 0.4),
                          ),
                          backgroundColor: c.linkAccent.withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // View Monitor Detail link
                      InkWell(
                        onTap: () => widget.onNavigateToTab('MONITOR'),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: c.subCardBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.borderDefault),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.monitor_heart_rounded,
                                  size: 13, color: c.linkAccent),
                              const SizedBox(width: 5),
                              Text(
                                s.hotspotOpenMonitor,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: c.linkAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 2. Bento Stat Cards Row
            Row(
              children: [
                Expanded(
                  child: BentoCard(
                    colors: c,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                s.hotspotDhcpClients,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: c.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.router_rounded,
                                size: 14, color: c.linkAccent),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${config.clientCount} / ${config.maxClients}',
                          style: TextStyle(
                            fontFamily: 'Cascadia Code',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          s.hotspotLeases,
                          style: TextStyle(fontSize: 9.5, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BentoCard(
                    colors: c,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                s.hotspotArpTitle,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: c.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.radar_rounded,
                                size: 14, color: c.accentEmerald),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.logic.connectedClients.length}',
                          style: TextStyle(
                            fontFamily: 'Cascadia Code',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          s.hotspotReachable,
                          style: TextStyle(fontSize: 9.5, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BentoCard(
                    colors: c,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                s.hotspotBandTitle,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: c.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.tune_rounded,
                                size: 14, color: c.accentAmber),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatBandLabel(config.band),
                          style: TextStyle(
                            fontFamily: 'Cascadia Code',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          s.hotspotBandFreq,
                          style: TextStyle(fontSize: 9.5, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 3. Wi-Fi Configuration Bento Card
            BentoCard(
              colors: c,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BentoSectionHeader(
                    title: titleConfig,
                    icon: Icons.wifi_password_rounded,
                    colors: c,
                  ),
                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SSID Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labelSsid,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _ssidController,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                prefixIcon: Icon(
                                  Icons.wifi_rounded,
                                  size: 17,
                                  color: c.linkAccent,
                                ),
                                filled: true,
                                fillColor: c.subCardBg,
                                hintText: s.hotspotSsidHint,
                                hintStyle: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: c.borderDefault),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: c.borderDefault),
                                ),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                      ? s.errFillRequired
                                      : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Password Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labelPassphrase,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontFamily:
                                    _obscurePassword ? null : 'Cascadia Code',
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 17,
                                  color: c.linkAccent,
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 17,
                                        color: c.textMuted,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.copy_rounded,
                                        size: 15,
                                        color: c.textMuted,
                                      ),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: _passwordController.text,
                                          ),
                                        );
                                        widget.onSnackbar(
                                          s.hotspotPasswordCopied,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                filled: true,
                                fillColor: c.subCardBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: c.borderDefault),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: c.borderDefault),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return s.errFillRequired;
                                }
                                if (val.trim().length < 8) {
                                  return s.hotspotPasswordShort;
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Band Selector with BentoSegmentedControl
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labelBand,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: BentoSegmentedControl<String>(
                                colors: c,
                                items: const [
                                  BentoSegmentItem(
                                    value: 'Auto',
                                    label: 'Auto',
                                    icon: Icons.autorenew_rounded,
                                  ),
                                  BentoSegmentItem(
                                    value: 'TwoPointFourGigahertz',
                                    label: '2.4 GHz',
                                    icon: Icons.wifi_rounded,
                                  ),
                                  BentoSegmentItem(
                                    value: 'FiveGigahertz',
                                    label: '5.0 GHz',
                                    icon: Icons.speed_rounded,
                                  ),
                                ],
                                groupValue: _selectedBand,
                                onValueChanged: (val) =>
                                    setState(() => _selectedBand = val),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Max clients limit
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labelMaxClients,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _maxClientsController,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontFamily: 'Cascadia Code',
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                prefixIcon: Icon(
                                  Icons.people_alt_rounded,
                                  size: 17,
                                  color: c.linkAccent,
                                ),
                                filled: true,
                                fillColor: c.subCardBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: c.borderDefault),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: c.borderDefault),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return s.errFillRequired;
                                }
                                final num = int.tryParse(val.trim());
                                if (num == null) {
                                  return s.hotspotNotNumber;
                                }
                                if (num < 1 || num > 128) {
                                  return s.hotspotClientRange;
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Save Button
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) {
                                return;
                              }
                              setState(() => _isSaving = true);
                              widget.onSnackbar(msgUpdating);

                              final maxClientsVal = int.tryParse(
                                      _maxClientsController.text.trim()) ??
                                  8;
                              final ok = await widget.logic.updateHotspotConfig(
                                _ssidController.text.trim(),
                                _passwordController.text.trim(),
                                _selectedBand,
                                maxClientsVal,
                              );

                              if (!mounted) return;
                              setState(() => _isSaving = false);
                              if (ok) {
                                widget.onSnackbar(msgSuccess);
                                final newConfig = widget.logic.hotspotConfig;
                                if (newConfig != null) {
                                  _ssidController.text = newConfig.ssid;
                                  _passwordController.text =
                                      newConfig.passphrase;
                                  _selectedBand = newConfig.band;
                                  _maxClientsController.text =
                                      newConfig.maxClients.toString();
                                }
                              } else {
                                widget.onSnackbar(msgError, isError: true);
                              }
                            },
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 17),
                      label: Text(
                        labelSave,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.linkAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 4. Notes & System Advice Bento Card
            BentoCard(
              colors: c,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.accentAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: c.accentAmber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.tips_and_updates_rounded,
                      size: 16,
                      color: c.accentAmber,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.hotspotSystemNote,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          noteText,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBandLabel(String band) {
    if (band.toLowerCase().contains('five')) return '5.0 GHz';
    if (band.toLowerCase().contains('two') || band.contains('2.4')) {
      return '2.4 GHz';
    }
    return 'Auto';
  }
}
