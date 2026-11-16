// lib/modules/ui/monitor_tab.dart
// Modern Bento Glassmorphic Monitor tab:
// - Interactive KPI Bento cards with 1-click quick filtering
// - FilterSearchDock with live search, status chips, and Card/Table view switcher
// - Intelligent Device Bento Cards & Compact Table View for connected clients

import 'package:flutter/material.dart';
import '../logic.dart';
import '../i18n.dart';
import '../services/app_power_manager.dart';
import 'bento_widgets.dart';
import 'styles.dart';
import 'widgets/monitor_bento_device_card.dart';
import 'widgets/monitor_compact_device_table.dart';
import 'widgets/monitor_hotspot_banner.dart';
import 'widgets/monitor_kpi_row.dart';
import 'widgets/visible_ui_listener.dart';

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
  late final VisibleUiListener _logicUiListener;

  TextEditingController get _searchController =>
      widget.searchController ??
      (_internalSearchController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _logicUiListener = VisibleUiListener(
      source: widget.logic,
      visibility: AppPowerManager.instance.windowVisibilityNotifier,
      onUpdate: _onLogicChanged,
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _logicUiListener.dispose();
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
      if (_selectedFilter == 'ALLOWED') {
        if (!client.isWhitelisted || client.isBlocked) return false;
      } else if (_selectedFilter == 'BLOCKED') {
        if (!isClientBlockedForDisplay(client, isGuardActive)) return false;
      } else if (_selectedFilter == 'PENDING') {
        if (client.isWhitelisted || isGuardActive || client.isBlocked) {
          return false;
        }
      }

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
    final blocked = clients
        .where((cl) => isClientBlockedForDisplay(cl, isGuardActive))
        .length;
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
        MonitorHotspotQuickControlBanner(
          logic: widget.logic,
          colors: c,
          isVi: isVi,
          isZh: isZh,
          onSnackbar: widget.onSnackbar,
          onNavigateToTab: widget.onNavigateToTab,
        ),
        const SizedBox(height: 8),
        MonitorBentoKpiRow(
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
        Expanded(
          child: filtered.isEmpty
              ? MonitorEmptyDeviceState(
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
                        return MonitorBentoDeviceCard(
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
                  : MonitorCompactDeviceTable(
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
