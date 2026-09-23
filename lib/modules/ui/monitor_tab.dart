// lib/modules/ui/monitor_tab.dart
// Modern Bento Glassmorphic Monitor tab:
// - Interactive KPI Bento cards with 1-click quick filtering
// - FilterSearchDock with live search, status chips, and Card/Table view switcher
// - Intelligent Device Bento Cards with categorized icons, 1-click MAC copy, inline rename, and distinct action pills
// - Compact Table View toggle for dense workstation monitoring

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic.dart';
import '../i18n.dart';
import 'styles.dart';
import 'bento_widgets.dart';

bool _isBlockedForDisplay(ClientDevice client, bool isGuardActive) {
  return client.isBlocked || (isGuardActive && !client.isWhitelisted);
}

class MonitorTab extends StatefulWidget {
  final WifiGuardLogic logic;
  final TextEditingController? searchController;
  final bool? hasSearchQuery;
  final void Function(ClientDevice client) onQuickBlock;
  final void Function(ClientDevice client) onQuickWhitelist;
  final void Function(String mac, String nickname) onEditNickname;
  final void Function(String message) onSnackbar;
  final ValueChanged<String>? onNavigateToTab;

  const MonitorTab({
    super.key,
    required this.logic,
    this.searchController,
    this.hasSearchQuery,
    required this.onQuickBlock,
    required this.onQuickWhitelist,
    required this.onEditNickname,
    required this.onSnackbar,
    this.onNavigateToTab,
  });

  @override
  State<MonitorTab> createState() => _MonitorTabState();
}

class _MonitorTabState extends State<MonitorTab> {
  String _selectedFilter = 'ALL'; // ALL, ALLOWED, BLOCKED, PENDING
  bool _isCardView = true;
  TextEditingController? _internalSearchController;

  TextEditingController get _searchController =>
      widget.searchController ??
      (_internalSearchController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    widget.logic.addListener(_onLogicChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    widget.logic.removeListener(_onLogicChanged);
    _internalSearchController?.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _onLogicChanged() {
    if (mounted) setState(() {});
  }

  List<ClientDevice> _getFilteredClients(List<ClientDevice> allClients) {
    final query = _searchController.text.trim().toLowerCase();
    final isGuardActive = widget.logic.isGuardActive;

    return allClients.where((client) {
      // 1. Status Filter
      if (_selectedFilter == 'ALLOWED') {
        if (!client.isWhitelisted || client.isBlocked) return false;
      } else if (_selectedFilter == 'BLOCKED') {
        if (!_isBlockedForDisplay(client, isGuardActive)) return false;
      } else if (_selectedFilter == 'PENDING') {
        // Pending approval: not whitelisted when guard is inactive
        if (client.isWhitelisted || isGuardActive || client.isBlocked) {
          return false;
        }
      }

      // 2. Search Query Filter
      if (query.isNotEmpty) {
        final matchesIp = client.ip.toLowerCase().contains(query);
        final matchesMac = client.mac.toLowerCase().contains(query);
        final matchesNick = client.nickname.toLowerCase().contains(query);
        if (!matchesIp && !matchesMac && !matchesNick) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final lang = context.languageNotifier.language;
    final isVi = lang == AppLanguage.vi;
    final isZh = lang == AppLanguage.zh;

    final clients = widget.logic.connectedClients;
    final total = clients.length;
    final isGuardActive = widget.logic.isGuardActive;
    final allowed =
        clients.where((cl) => cl.isWhitelisted && !cl.isBlocked).length;
    final blocked =
        clients.where((cl) => _isBlockedForDisplay(cl, isGuardActive)).length;
    final pending = (!isGuardActive)
        ? clients.where((cl) => !cl.isWhitelisted && !cl.isBlocked).length
        : 0;

    final filtered = _getFilteredClients(clients);

    final filterChips = [
      FilterChipData(
        key: 'ALL',
        label: isVi ? 'Tất cả' : (isZh ? '全部' : 'All'),
        count: total,
        activeColor: c.accentCyan,
        icon: Icons.all_inclusive_rounded,
      ),
      FilterChipData(
        key: 'ALLOWED',
        label: isVi ? 'Đã duyệt' : (isZh ? '已允许' : 'Allowed'),
        count: allowed,
        activeColor: c.accentEmerald,
        icon: Icons.verified_user_rounded,
      ),
      FilterChipData(
        key: 'BLOCKED',
        label: isVi ? 'Bị chặn' : (isZh ? '已拦截' : 'Blocked'),
        count: blocked,
        activeColor: c.accentRose,
        icon: Icons.gpp_bad_rounded,
      ),
      if (pending > 0 || !isGuardActive)
        FilterChipData(
          key: 'PENDING',
          label: isVi ? 'Chờ duyệt' : (isZh ? '待处理' : 'Pending'),
          count: pending,
          activeColor: c.accentAmber,
          icon: Icons.hourglass_top_rounded,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Quick Hotspot & ICS Repair Control Banner ─────────────────────────
        _HotspotQuickControlBanner(
          logic: widget.logic,
          colors: c,
          isVi: isVi,
          isZh: isZh,
          onSnackbar: widget.onSnackbar,
          onNavigateToTab: widget.onNavigateToTab,
        ),
        const SizedBox(height: 8),

        // ── Interactive KPI Bento Grid ────────────────────────────────────────
        _BentoKpiRow(
          total: total,
          allowed: allowed,
          blocked: blocked,
          selectedFilter: _selectedFilter,
          colors: c,
          isVi: isVi,
          isZh: isZh,
          onSelectFilter: (filterKey) {
            setState(() {
              _selectedFilter =
                  (_selectedFilter == filterKey) ? 'ALL' : filterKey;
            });
          },
        ),
        const SizedBox(height: 8),

        // ── Filter & Search Dock ─────────────────────────────────────────────
        FilterSearchDock(
          colors: c,
          searchController: _searchController,
          searchHint: isVi
              ? 'Tìm kiếm theo IP, MAC hoặc tên thiết bị...'
              : (isZh
                  ? '按 IP、MAC 或设备名称搜索...'
                  : 'Search by IP, MAC, or device name...'),
          onSearchChanged: (_) => setState(() {}),
          onClearSearch: () {
            _searchController.clear();
            setState(() {});
          },
          filters: filterChips,
          selectedFilter: _selectedFilter,
          onFilterSelected: (key) => setState(() => _selectedFilter = key),
          isCardView: _isCardView,
          onViewModeChanged: (val) => setState(() => _isCardView = val),
        ),
        const SizedBox(height: 8),

        // ── Device Content Area (Bento Cards or Compact Table) ───────────────
        Expanded(
          child: filtered.isEmpty
              ? _EmptyDeviceState(
                  colors: c,
                  isVi: isVi,
                  isZh: isZh,
                  hasFilter: _selectedFilter != 'ALL' ||
                      _searchController.text.isNotEmpty,
                  onResetFilter: () {
                    setState(() {
                      _selectedFilter = 'ALL';
                      _searchController.clear();
                    });
                  },
                )
              : (_isCardView
                  ? ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        return _BentoDeviceCard(
                          key: ValueKey(filtered[index].mac),
                          client: filtered[index],
                          isGuardActive: isGuardActive,
                          colors: c,
                          isVi: isVi,
                          isZh: isZh,
                          onQuickBlock: widget.onQuickBlock,
                          onQuickWhitelist: widget.onQuickWhitelist,
                          onEditNickname: widget.onEditNickname,
                          onSnackbar: widget.onSnackbar,
                        );
                      },
                    )
                  : _CompactDeviceTable(
                      filtered: filtered,
                      isGuardActive: isGuardActive,
                      colors: c,
                      isVi: isVi,
                      isZh: isZh,
                      onQuickBlock: widget.onQuickBlock,
                      onQuickWhitelist: widget.onQuickWhitelist,
                      onEditNickname: widget.onEditNickname,
                      onSnackbar: widget.onSnackbar,
                    )),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets (Extracted to keep nesting < 4 levels per AGENTS.md rule 1)
// ─────────────────────────────────────────────────────────────────────────────

class _HotspotQuickControlBanner extends StatefulWidget {
  final WifiGuardLogic logic;
  final AppColors colors;
  final bool isVi;
  final bool isZh;
  final void Function(String message) onSnackbar;
  final ValueChanged<String>? onNavigateToTab;

  const _HotspotQuickControlBanner({
    required this.logic,
    required this.colors,
    required this.isVi,
    required this.isZh,
    required this.onSnackbar,
    this.onNavigateToTab,
  });

  @override
  State<_HotspotQuickControlBanner> createState() =>
      _HotspotQuickControlBannerState();
}

class _HotspotQuickControlBannerState
    extends State<_HotspotQuickControlBanner> {
  bool _isToggling = false;
  bool _isFixingIcs = false;

  bool get _isBusy => _isToggling || _isFixingIcs;

  Future<void> _onToggleHotspot(bool val) async {
    if (_isBusy) return;
    setState(() => _isToggling = true);
    final ok = await widget.logic.setHotspotState(val);
    if (!mounted) return;
    setState(() => _isToggling = false);
    if (ok) {
      widget.onSnackbar(widget.isVi
          ? 'Đã chuyển đổi trạng thái Hotspot'
          : (widget.isZh ? '已切换移动热点状态' : 'Hotspot state changed'));
    } else {
      widget.onSnackbar(
        widget.isVi
            ? 'Chuyển đổi Hotspot thất bại!'
            : (widget.isZh ? '热点切换失败！' : 'Failed to toggle hotspot!'),
      );
    }
  }

  Future<void> _onFixIcs() async {
    if (_isBusy) return;
    setState(() => _isFixingIcs = true);
    widget.onSnackbar(widget.isVi
        ? 'Đang buộc dừng PID và khởi động lại dịch vụ ICS...'
        : (widget.isZh
            ? '正在强制停止并重启ICS服务...'
            : 'Killing ICS PID & restarting SharedAccess...'));
    final ok = await widget.logic.repairIcsService();
    if (!mounted) return;
    setState(() => _isFixingIcs = false);
    if (ok) {
      widget.onSnackbar(widget.isVi
          ? 'Dịch vụ ICS đã khởi động lại thành công!'
          : (widget.isZh
              ? 'ICS服务修复并重启成功！'
              : 'ICS service repaired & restarted successfully!'));
    } else {
      widget.onSnackbar(
        widget.isVi
            ? 'Khởi động lại dịch vụ ICS thất bại!'
            : (widget.isZh ? 'ICS服务重启失败！' : 'Failed to restart ICS service!'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.logic.hotspotConfig;
    final isHotspotOn = config?.state.toLowerCase() == 'enabled';
    final ssid = config?.ssid.isNotEmpty == true
        ? config!.ssid
        : (widget.isVi ? 'Hotspot Chưa Cấu Hình' : 'Mobile Hotspot');

    final bandText = config?.band != null
        ? (config!.band == 'TwoPointFourGigahertz'
            ? '2.4 GHz'
            : (config.band == 'FiveGigahertz'
                ? '5.0 GHz'
                : (config.band == 'SixGigahertz' ? '6.0 GHz' : config.band)))
        : 'Auto';

    return BentoCard(
      colors: widget.colors,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Hotspot indicator icon container
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isHotspotOn
                  ? widget.colors.accentEmerald.withValues(alpha: 0.14)
                  : widget.colors.subCardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHotspotOn
                    ? widget.colors.accentEmerald.withValues(alpha: 0.35)
                    : widget.colors.subCardBorder,
              ),
            ),
            child: Icon(
              Icons.wifi_tethering_rounded,
              color: isHotspotOn
                  ? widget.colors.accentEmerald
                  : widget.colors.textMuted,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),

          // Hotspot information & status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ssid,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: widget.colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    PillBadge(
                      label: isHotspotOn ? 'ONLINE' : 'OFFLINE',
                      color: isHotspotOn
                          ? widget.colors.accentEmerald
                          : widget.colors.textMuted,
                      bg: isHotspotOn
                          ? widget.colors.accentEmerald.withValues(alpha: 0.12)
                          : widget.colors.subCardBg,
                      border: isHotspotOn
                          ? widget.colors.accentEmerald.withValues(alpha: 0.35)
                          : widget.colors.subCardBorder,
                      showDot: true,
                      fontSize: 9.5,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: widget.colors.subCardBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: widget.colors.subCardBorder),
                      ),
                      child: Text(
                        bandText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: widget.colors.textSecondary,
                          fontFamily: 'Cascadia Code',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isHotspotOn
                      ? (widget.isVi
                          ? 'Đang phát • DHCP: ${config?.clientCount ?? 0}/${config?.maxClients ?? 8} thiết bị'
                          : 'Broadcasting • DHCP: ${config?.clientCount ?? 0}/${config?.maxClients ?? 8}')
                      : (widget.isVi
                          ? 'Hotspot đang tắt. Bật switch bên phải để phát sóng.'
                          : 'Hotspot off. Toggle switch to start.'),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: widget.colors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Actions: Sửa lỗi ICS button + Cấu hình button + Switch
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ICS Repair Quick Action
              _isFixingIcs
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.colors.accentAmber,
                        ),
                      ),
                    )
                  : Tooltip(
                      message: widget.isVi
                          ? 'Dừng PID tiến trình SharedAccess và khởi động lại dịch vụ ICS'
                          : 'Kill stuck ICS PID and restart SharedAccess service',
                      child: InkWell(
                        key: const Key('monitor-hotspot-fix-ics'),
                        onTap: _isBusy ? null : _onFixIcs,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.colors.accentAmber
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: widget.colors.accentAmber
                                  .withValues(alpha: 0.32),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.build_circle_outlined,
                                  size: 13, color: widget.colors.accentAmber),
                              const SizedBox(width: 4),
                              Text(
                                widget.isVi
                                    ? 'Sửa lỗi ICS'
                                    : (widget.isZh ? '修复ICS' : 'Fix ICS'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.colors.accentAmber,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              const SizedBox(width: 6),

              // Navigate to Hotspot Tab for Full Config
              if (widget.onNavigateToTab != null)
                Tooltip(
                  message: widget.isVi
                      ? 'Chuyển sang tab Cấu hình Wi-Fi'
                      : 'Configure SSID, password, and frequency band',
                  child: InkWell(
                    key: const Key('monitor-hotspot-config'),
                    onTap: () => widget.onNavigateToTab!('HOTSPOT'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.colors.subCardBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: widget.colors.subCardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded,
                              size: 13, color: widget.colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            widget.isVi
                                ? 'Cấu hình'
                                : (widget.isZh ? '配置' : 'Config'),
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 6),

              // Switch ON / OFF
              _isToggling
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: Padding(
                        padding: EdgeInsets.all(3.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Tooltip(
                      message: isHotspotOn
                          ? (widget.isVi ? 'Tắt Hotspot' : 'Turn Off Hotspot')
                          : (widget.isVi ? 'Bật Hotspot' : 'Turn On Hotspot'),
                      child: Transform.scale(
                        scale: 0.85,
                        child: Switch.adaptive(
                          key: const Key('monitor-hotspot-toggle'),
                          value: isHotspotOn,
                          activeThumbColor: widget.colors.accentEmerald,
                          onChanged: _isBusy ? null : _onToggleHotspot,
                        ),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BentoKpiRow extends StatelessWidget {
  final int total;
  final int allowed;
  final int blocked;
  final String selectedFilter;
  final AppColors colors;
  final bool isVi;
  final bool isZh;
  final ValueChanged<String> onSelectFilter;

  const _BentoKpiRow({
    required this.total,
    required this.allowed,
    required this.blocked,
    required this.selectedFilter,
    required this.colors,
    required this.isVi,
    required this.isZh,
    required this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InteractiveKpiCard(
            title:
                isVi ? 'Tổng kết nối' : (isZh ? '已连接设备' : 'Connected Clients'),
            value: '$total',
            subtitle: isVi
                ? 'Đang phát sóng Wi-Fi'
                : (isZh ? '活跃网络连接' : 'Active Wi-Fi clients'),
            icon: Icons.devices_rounded,
            color: colors.accentCyan,
            isSelected: selectedFilter == 'ALL',
            colors: colors,
            onTap: () => onSelectFilter('ALL'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InteractiveKpiCard(
            title: isVi ? 'Đã duyệt' : (isZh ? '白名单允许' : 'Allowed / Secure'),
            value: '$allowed',
            subtitle: isVi
                ? 'An toàn & Tin cậy'
                : (isZh ? '受信任安全设备' : 'Verified in whitelist'),
            icon: Icons.verified_user_rounded,
            color: colors.accentEmerald,
            isSelected: selectedFilter == 'ALLOWED',
            colors: colors,
            onTap: () => onSelectFilter('ALLOWED'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InteractiveKpiCard(
            title:
                isVi ? 'Bị chặn / Lạ' : (isZh ? '已拦截设备' : 'Blocked Intruders'),
            value: '$blocked',
            subtitle: blocked > 0
                ? (isVi ? 'Ngoài Whitelist' : 'Untrusted devices')
                : (isVi ? 'Mạng an toàn' : 'All secure'),
            icon: Icons.gpp_bad_rounded,
            color: colors.accentRose,
            isSelected: selectedFilter == 'BLOCKED',
            glow: blocked > 0,
            colors: colors,
            onTap: () => onSelectFilter('BLOCKED'),
          ),
        ),
      ],
    );
  }
}

class _InteractiveKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool glow;
  final VoidCallback onTap;
  final AppColors colors;

  const _InteractiveKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    this.glow = false,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      onTap: onTap,
      isFeatured: isSelected || glow,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      customBorder: isSelected
          ? color.withValues(alpha: 0.65)
          : (glow ? color.withValues(alpha: 0.4) : null),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.32)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final showFilterBadge =
                        isSelected && constraints.maxWidth >= 140;
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colors.textMuted,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showFilterBadge) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              'FILTER',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: color,
                                fontFamily: 'Cascadia Code',
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cascadia Code',
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoDeviceCard extends StatelessWidget {
  final ClientDevice client;
  final bool isGuardActive;
  final AppColors colors;
  final bool isVi;
  final bool isZh;
  final void Function(ClientDevice) onQuickBlock;
  final void Function(ClientDevice) onQuickWhitelist;
  final void Function(String mac, String nickname) onEditNickname;
  final void Function(String) onSnackbar;

  const _BentoDeviceCard({
    super.key,
    required this.client,
    required this.isGuardActive,
    required this.colors,
    required this.isVi,
    required this.isZh,
    required this.onQuickBlock,
    required this.onQuickWhitelist,
    required this.onEditNickname,
    required this.onSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    final isWhitelisted = client.isWhitelisted;
    final isBlocked = _isBlockedForDisplay(client, isGuardActive);
    final displayName =
        DeviceTypeHelper.getDisplayName(client.nickname, client.mac);
    final deviceIcon =
        DeviceTypeHelper.getDeviceIcon(client.nickname, client.ip);

    final statusColor = isWhitelisted && !client.isBlocked
        ? colors.accentEmerald
        : (isBlocked ? colors.accentRose : colors.accentAmber);

    final statusLabel = isWhitelisted && !client.isBlocked
        ? (isVi ? 'ĐÃ DUYỆT' : (isZh ? '已允许' : 'ALLOWED'))
        : (isBlocked
            ? (isVi ? 'BỊ CHẶN' : (isZh ? '已拦截' : 'BLOCKED'))
            : (isVi ? 'CHỜ DUYỆT' : (isZh ? '待处理' : 'PENDING')));

    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Device category avatar box
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.subCardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.subCardBorder),
            ),
            child: Icon(deviceIcon, color: statusColor, size: 16),
          ),
          const SizedBox(width: 10),

          // Central identity info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => onEditNickname(client.mac, client.nickname),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PillBadge(
                      label: statusLabel,
                      color: statusColor,
                      bg: statusColor.withValues(alpha: 0.12),
                      border: statusColor.withValues(alpha: 0.32),
                      showDot: true,
                      fontSize: 9,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // IP tag
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lan_rounded,
                            size: 12, color: colors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          client.ip,
                          style: TextStyle(
                            fontFamily: 'Cascadia Code',
                            fontSize: 11.5,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    // 1-Click MAC Copy chip
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: client.mac));
                        onSnackbar(isVi
                            ? 'Đã sao chép MAC: ${client.mac}'
                            : 'Copied MAC: ${client.mac}');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.subCardBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.subCardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded,
                                size: 10, color: colors.linkAccent),
                            const SizedBox(width: 3),
                            Text(
                              client.mac,
                              style: TextStyle(
                                fontFamily: 'Cascadia Code',
                                fontSize: 11,
                                color: colors.linkAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Active connection pulse dot
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.accentEmerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          client.state.isNotEmpty ? client.state : 'Active',
                          style: TextStyle(
                              fontSize: 10.5, color: colors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Primary inline action pill
          if (isWhitelisted && !client.isBlocked)
            InkWell(
              onTap: () => onQuickBlock(client),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.accentRose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: colors.accentRose.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block_flipped,
                        size: 12, color: colors.accentRose),
                    const SizedBox(width: 5),
                    Text(
                      isVi ? 'Chặn' : (isZh ? '拦截' : 'Block'),
                      style: TextStyle(
                        color: colors.accentRose,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            InkWell(
              onTap: () => onQuickWhitelist(client),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.accentEmerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: colors.accentEmerald.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_rounded,
                        size: 12, color: colors.accentEmerald),
                    const SizedBox(width: 5),
                    Text(
                      isVi ? 'Cho phép' : (isZh ? '允许' : 'Allow'),
                      style: TextStyle(
                        color: colors.accentEmerald,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactDeviceTable extends StatelessWidget {
  final List<ClientDevice> filtered;
  final bool isGuardActive;
  final AppColors colors;
  final bool isVi;
  final bool isZh;
  final void Function(ClientDevice) onQuickBlock;
  final void Function(ClientDevice) onQuickWhitelist;
  final void Function(String mac, String nickname) onEditNickname;
  final void Function(String) onSnackbar;

  const _CompactDeviceTable({
    required this.filtered,
    required this.isGuardActive,
    required this.colors,
    required this.isVi,
    required this.isZh,
    required this.onQuickBlock,
    required this.onQuickWhitelist,
    required this.onEditNickname,
    required this.onSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Table header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: colors.subCardBg,
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text('#',
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('IP',
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('MAC Address',
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(isVi ? 'Tên thiết bị' : 'Device Name',
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 100,
                  child: Text(isVi ? 'Trạng thái' : 'Status',
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 70,
                  child: Text(isVi ? 'Thao tác' : 'Action',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Divider(color: colors.subCardBorder, height: 1),
          // Table rows
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  Divider(color: colors.subCardBorder, height: 1),
              itemBuilder: (context, index) {
                final client = filtered[index];
                final isWhitelisted = client.isWhitelisted;
                final isBlocked = _isBlockedForDisplay(client, isGuardActive);
                final statusColor = isWhitelisted && !client.isBlocked
                    ? colors.accentEmerald
                    : (isBlocked ? colors.accentRose : colors.accentAmber);

                return Padding(
                  key: ValueKey(client.mac),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text('${index + 1}',
                            style: TextStyle(
                                color: colors.textMuted, fontSize: 11)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          client.ip,
                          style: TextStyle(
                            fontFamily: 'Cascadia Code',
                            fontSize: 12,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: client.mac));
                            onSnackbar('Copied MAC: ${client.mac}');
                          },
                          child: Text(
                            client.mac,
                            style: TextStyle(
                              fontFamily: 'Cascadia Code',
                              fontSize: 12,
                              color: colors.linkAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          DeviceTypeHelper.getDisplayName(
                              client.nickname, client.mac),
                          style: TextStyle(
                              color: colors.textPrimary, fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: PillBadge(
                          label: isWhitelisted && !client.isBlocked
                              ? (isVi ? 'ĐÃ DUYỆT' : 'ALLOWED')
                              : (isBlocked
                                  ? (isVi ? 'BỊ CHẶN' : 'BLOCKED')
                                  : (isVi ? 'CHỜ DUYỆT' : 'PENDING')),
                          color: statusColor,
                          bg: statusColor.withValues(alpha: 0.12),
                          border: statusColor.withValues(alpha: 0.35),
                          showDot: true,
                          fontSize: 10,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: isWhitelisted && !client.isBlocked
                              ? IconButton(
                                  icon: Icon(Icons.block_flipped,
                                      size: 16, color: colors.accentRose),
                                  tooltip: 'Block',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                  onPressed: () => onQuickBlock(client),
                                )
                              : IconButton(
                                  icon: Icon(Icons.verified_user_rounded,
                                      size: 16, color: colors.accentEmerald),
                                  tooltip: 'Whitelist',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                  onPressed: () => onQuickWhitelist(client),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDeviceState extends StatelessWidget {
  final AppColors colors;
  final bool isVi;
  final bool isZh;
  final bool hasFilter;
  final VoidCallback onResetFilter;

  const _EmptyDeviceState({
    required this.colors,
    required this.isVi,
    required this.isZh,
    required this.hasFilter,
    required this.onResetFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BentoCard(
        colors: colors,
        borderRadius: 16,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.subCardBg,
                shape: BoxShape.circle,
                border: Border.all(color: colors.subCardBorder),
              ),
              child: Icon(
                hasFilter ? Icons.search_off_rounded : Icons.wifi_off_rounded,
                size: 28,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? (isVi
                      ? 'Không tìm thấy thiết bị phù hợp'
                      : (isZh ? '没有匹配的设备' : 'No matching devices found'))
                  : (isVi
                      ? 'Chưa có thiết bị nào kết nối'
                      : (isZh ? '当前无设备连接' : 'No connected clients')),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilter
                  ? (isVi
                      ? 'Thử thay đổi từ khóa hoặc bộ lọc danh sách.'
                      : (isZh
                          ? '请尝试清除搜索条件或选择其他过滤器。'
                          : 'Try adjusting your search query or status filter.'))
                  : (isVi
                      ? 'Khi có thiết bị kết nối vào trạm phát Hotspot, thiết bị sẽ xuất hiện tại đây.'
                      : (isZh
                          ? '当有设备连接到移动热点时，将在此处列出。'
                          : 'Devices will appear here when connected to the mobile hotspot.')),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onResetFilter,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(isVi ? 'Đặt lại bộ lọc' : 'Reset Filter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.linkAccent,
                  side: BorderSide(
                      color: colors.linkAccent.withValues(alpha: 0.4)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Backward Compatibility Stubs (for any external reference to StatCard/ClientRow)
// ─────────────────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool glow;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return BentoCard(
      colors: c,
      isFeatured: glow,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    color: c.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ClientRow extends StatelessWidget {
  final ClientDevice client;
  final int index;
  final bool isGuardActive;
  final void Function(ClientDevice client) onQuickBlock;
  final void Function(ClientDevice client) onQuickWhitelist;
  final void Function(String mac, String nickname) onEditNickname;
  final void Function(String message) onSnackbar;

  const ClientRow({
    super.key,
    required this.client,
    required this.index,
    required this.isGuardActive,
    required this.onQuickBlock,
    required this.onQuickWhitelist,
    required this.onEditNickname,
    required this.onSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isVi = context.languageNotifier.language == AppLanguage.vi;
    final isZh = context.languageNotifier.language == AppLanguage.zh;

    return _BentoDeviceCard(
      client: client,
      isGuardActive: isGuardActive,
      colors: c,
      isVi: isVi,
      isZh: isZh,
      onQuickBlock: onQuickBlock,
      onQuickWhitelist: onQuickWhitelist,
      onEditNickname: onEditNickname,
      onSnackbar: onSnackbar,
    );
  }
}
