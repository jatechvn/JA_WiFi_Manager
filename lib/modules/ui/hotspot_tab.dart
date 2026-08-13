// lib/modules/ui/hotspot_tab.dart
// Hotspot tab: Windows Mobile Hotspot status and Wi-Fi configuration form.
//
// Self-contained StatefulWidget — owns its form/loading/controller state and
// syncs from WifiGuardLogic.hotspotConfig itself (via its own listener),
// since none of that state is read anywhere outside this tab.

import 'package:flutter/material.dart';
import '../logic.dart';
import '../i18n.dart';
import 'styles.dart';

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
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isFixingDhcp = false;

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
    final lang = context.languageNotifier.language;
    final config = widget.logic.hotspotConfig;

    final isVi = lang == AppLanguage.vi;
    final isZh = lang == AppLanguage.zh;

    final titleStatus = isVi
        ? 'Trạng thái phát sóng'
        : isZh
            ? '热点运行状态'
            : 'Mobile Hotspot Status';
    final titleConfig = isVi
        ? 'Cấu hình mạng Wi-Fi'
        : isZh
            ? '无线网络配置'
            : 'Wi-Fi Network Configuration';
    final labelSwitch = isVi
        ? 'Bật điểm phát sóng'
        : isZh
            ? '开启移动热点'
            : 'Enable Mobile Hotspot';
    final labelSsid = isVi
        ? 'Tên Wi-Fi (SSID)'
        : isZh
            ? '网络名称 (SSID)'
            : 'Network Name (SSID)';
    final labelPassphrase = isVi
        ? 'Mật khẩu Wi-Fi'
        : isZh
            ? '网络密码 (WPA2)'
            : 'Network Password (WPA2)';
    final labelBand = isVi
        ? 'Băng tần'
        : isZh
            ? '网络频段'
            : 'Network Band';
    final labelSave = isVi
        ? 'Lưu cấu hình'
        : isZh
            ? '保存设置'
            : 'Save Configuration';
    final msgUpdating = isVi
        ? 'Đang cập nhật cấu hình...'
        : isZh
            ? '正在更新配置...'
            : 'Updating hotspot settings...';
    final msgSuccess = isVi
        ? 'Đã cập nhật cấu hình hotspot!'
        : isZh
            ? '热点配置更新成功!'
            : 'Hotspot settings updated successfully!';
    final msgError = isVi
        ? 'Cập nhật thất bại!'
        : isZh
            ? '更新失败!'
            : 'Failed to update settings!';
    final noteText = isVi
        ? 'Lưu ý: Tính năng này thay đổi trực tiếp cấu hình Mobile Hotspot mặc định của Windows. Bạn có thể thay đổi giới hạn số thiết bị tối đa (mặc định là 8, yêu cầu quyền Administrator và có thể cần bật/tắt lại Hotspot).'
        : isZh
            ? '注意: 此功能将直接修改 Windows 默认的移动热点配置。您可以修改最大连接数限制（默认为 8，需管理员权限，可能需要重新开关热点生效）。'
            : 'Note: This feature configures the default Windows Mobile Hotspot. You can change the maximum client limit (default is 8, requires Administrator permissions, and may require toggling the Hotspot to apply).';
    final labelMaxClients = isVi
        ? 'Giới hạn kết nối (1-128)'
        : isZh
            ? '连接限制数 (1-128)'
            : 'Max Clients Limit (1-128)';

    if (config == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: c.linkAccent),
            const SizedBox(height: 16),
            Text(
              isVi
                  ? 'Đang tải thông tin Hotspot...'
                  : isZh
                      ? '正在获取热点配置...'
                      : 'Loading Hotspot configurations...',
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
            // Row for Status and Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Turn On/Off Switch Card
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StyledWidgets.sectionHeader(titleStatus, c,
                            icon: Icons.sensors),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  labelSwitch,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isHotspotOn
                                            ? c.statusActive
                                            : c.statusRemoved,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      config.state.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isHotspotOn
                                            ? c.statusActive
                                            : c.statusRemoved,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Switch.adaptive(
                                    value: isHotspotOn,
                                    activeThumbColor: c.statusActive,
                                    onChanged: (val) async {
                                      setState(() => _isLoading = true);
                                      final ok = await widget.logic
                                          .setHotspotState(val);
                                      setState(() => _isLoading = false);
                                      if (ok) {
                                        widget.onSnackbar(isVi
                                            ? 'Đã chuyển đổi trạng thái hotspot'
                                            : 'Hotspot state changed');
                                      } else {
                                        widget.onSnackbar(
                                            isVi
                                                ? 'Chuyển đổi thất bại!'
                                                : 'Failed to toggle hotspot!',
                                            isError: true);
                                      }
                                    },
                                  ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isVi
                                  ? 'Cấp phát IP (DHCP)'
                                  : isZh
                                      ? 'DHCP 客户端'
                                      : 'DHCP Clients',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${config.clientCount} / ${config.maxClients}',
                              style: TextStyle(
                                fontSize: 13,
                                color: c.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cascadia Code',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isVi
                                  ? 'Quét thực tế (ARP)'
                                  : isZh
                                      ? '活动扫描 (ARP)'
                                      : 'Active Scan (ARP)',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                  fontWeight: FontWeight.w600),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${widget.logic.connectedClients.length}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cascadia Code',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () =>
                                      widget.onNavigateToTab('MONITOR'),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          c.linkAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: c.linkAccent
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.visibility_outlined,
                                            size: 12, color: c.linkAccent),
                                        const SizedBox(width: 4),
                                        Text(
                                          isVi
                                              ? 'Xem chi tiết'
                                              : isZh
                                                  ? '查看详情'
                                                  : 'View Details',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.linkAccent,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info card
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StyledWidgets.sectionHeader(
                            isVi
                                ? 'Thông tin thiết bị'
                                : isZh
                                    ? '网络详情'
                                    : 'Network Details',
                            c,
                            icon: Icons.info_outline),
                        const SizedBox(height: 12),
                        Text(
                          noteText,
                          style: TextStyle(
                              fontSize: 12,
                              color: c.textSecondary,
                              height: 1.6),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shield_outlined,
                                    size: 14, color: c.statusActive),
                                const SizedBox(width: 6),
                                Text(
                                  isVi
                                      ? 'Đang bảo vệ Whitelist'
                                      : isZh
                                          ? '白名单保护已激活'
                                          : 'Whitelist guard active',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: c.textMuted,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            _isFixingDhcp
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: c.linkAccent),
                                  )
                                : InkWell(
                                    onTap: () async {
                                      setState(() => _isFixingDhcp = true);
                                      widget.onSnackbar(isVi
                                          ? 'Đang sửa lỗi IP/DHCP Hotspot...'
                                          : 'Fixing Hotspot IP/DHCP...');
                                      final ok =
                                          await widget.logic.fixHotspotDhcp();
                                      setState(() => _isFixingDhcp = false);
                                      if (ok) {
                                        widget.onSnackbar(isVi
                                            ? 'Sửa lỗi thành công! Hãy bật lại Hotspot.'
                                            : 'Fix completed! Please enable Hotspot.');
                                      } else {
                                        widget.onSnackbar(
                                            isVi
                                                ? 'Sửa lỗi thất bại!'
                                                : 'Failed to fix connection!',
                                            isError: true);
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        Icon(Icons.build_circle_outlined,
                                            size: 14, color: c.linkAccent),
                                        const SizedBox(width: 4),
                                        Text(
                                          isVi
                                              ? 'Sửa lỗi IP/DHCP'
                                              : isZh
                                                  ? '修复IP/DHCP错误'
                                                  : 'Fix IP/DHCP Error',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: c.linkAccent,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Wi-Fi Config card
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StyledWidgets.sectionHeader(titleConfig, c,
                      icon: Icons.wifi_password),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SSID field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(labelSsid,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: c.textSecondary)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _ssidController,
                              style:
                                  TextStyle(color: c.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.wifi, size: 16),
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

                      // Password field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(labelPassphrase,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: c.textSecondary)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 13,
                                  fontFamily: _obscurePassword
                                      ? null
                                      : 'Cascadia Code'),
                              decoration: InputDecoration(
                                prefixIcon:
                                    const Icon(Icons.lock_outline, size: 16),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 16,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return s.errFillRequired;
                                }
                                if (val.trim().length < 8) {
                                  return isVi
                                      ? 'Mật khẩu phải từ 8 ký tự trở lên'
                                      : 'Password must be at least 8 characters';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Band field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(labelBand,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: c.textSecondary)),
                            const SizedBox(height: 6),
                            Container(
                              height: 42,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: c.bgTertiary,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: c.borderDefault),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedBand,
                                underline: const SizedBox(),
                                isExpanded: true,
                                dropdownColor: c.bgSecondary,
                                style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'Auto',
                                      child: Text('Auto (Recommended)')),
                                  DropdownMenuItem(
                                      value: 'TwoPointFourGigahertz',
                                      child: Text('2.4 GHz')),
                                  DropdownMenuItem(
                                      value: 'FiveGigahertz',
                                      child: Text('5.0 GHz')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedBand = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Max clients limit field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(labelMaxClients,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: c.textSecondary)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _maxClientsController,
                              style:
                                  TextStyle(color: c.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                prefixIcon:
                                    Icon(Icons.people_alt_outlined, size: 16),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return s.errFillRequired;
                                }
                                final num = int.tryParse(val.trim());
                                if (num == null) {
                                  return isVi
                                      ? 'Phải là chữ số'
                                      : 'Must be a number';
                                }
                                if (num < 1 || num > 128) {
                                  return isVi
                                      ? 'Giới hạn từ 1 đến 128'
                                      : 'Must be between 1 and 128';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Save button spanning full width
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) {
                                return;
                              }
                              setState(() => _isLoading = true);
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

                              setState(() => _isLoading = false);
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
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 16),
                      label: Text(labelSave),
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
}
