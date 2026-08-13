// lib/modules/ui/main_window.dart
// Main visual dashboard window widget for JA WiFi Hotspot Guard (Fluent Refactored layout)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../logic.dart';
import '../i18n.dart';
import '../utils.dart';
import '../app_config.dart';
import 'styles.dart';
import 'dialogs.dart';
import 'monitor_tab.dart';
import 'settings_tab.dart';
import 'sidebar.dart';
import 'whitelist_tab.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

class MainWindow extends StatefulWidget {
  final WifiGuardLogic logic;
  final ThemeNotifier themeNotifier;
  final LanguageNotifier languageNotifier;

  const MainWindow({
    super.key,
    required this.logic,
    required this.themeNotifier,
    required this.languageNotifier,
  });

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow>
    with WindowListener, TrayListener {
  AppColors get _c => widget.themeNotifier.colors;
  AppStrings get _s => widget.languageNotifier.strings;

  bool _isLoading = true;
  bool _isClosing = false;
  bool _isAdmin = false;
  String _activeTab = 'MONITOR'; // MONITOR, WHITELIST, CONSOLE, SETTINGS

  // Preference states
  bool _startupWithWindows = false;
  bool _startMinimized = false;
  bool _closeToTray = false;
  bool _autoStartGuard = false;
  bool _autoStartHotspot = false;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();

  // Hotspot config controls
  final _hotspotFormKey = GlobalKey<FormState>();
  final TextEditingController _hotspotSsidController = TextEditingController();
  final TextEditingController _hotspotPasswordController =
      TextEditingController();
  final TextEditingController _hotspotMaxClientsController =
      TextEditingController();
  String _selectedHotspotBand = 'Auto';
  bool _isHotspotLoading = false;
  bool _obscureHotspotPassword = true;
  bool _isFixingDhcp = false;

  Timer? _refreshTimer;
  final GlobalKey _themeButtonKey = GlobalKey();

  // Logs filtering option
  String _logLevelFilter = 'ALL'; // ALL, BLOCKS, WARNINGS
  bool _autoScrollLogs = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initTray();
    _initialize();

    // Periodically refresh clients only when guard is inactive and we are on a viewing tab
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        if (!widget.logic.isGuardActive) {
          if (_activeTab == 'MONITOR' || _activeTab == 'WHITELIST') {
            widget.logic.scanConnectedClients();
          }
        }
      }
    });

    widget.languageNotifier.addListener(_onLanguageChange);
    widget.logic.addListener(_onLogicChange);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    trayManager.destroy();
    widget.languageNotifier.removeListener(_onLanguageChange);
    widget.logic.removeListener(_onLogicChange);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _logScrollController.dispose();
    _hotspotSsidController.dispose();
    _hotspotPasswordController.dispose();
    _hotspotMaxClientsController.dispose();
    super.dispose();
  }

  void _onLanguageChange() {
    if (mounted) {
      _initTray();
      setState(() {});
    }
  }

  Future<void> _initTray() async {
    try {
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
      );
      await trayManager.setToolTip('JA WiFi Hotspot Guard');

      final menuItems = [
        MenuItem(
          key: 'show_window',
          label: widget.languageNotifier.language == AppLanguage.vi
              ? 'Hiện cửa sổ'
              : widget.languageNotifier.language == AppLanguage.zh
                  ? '显示主窗口'
                  : 'Show Window',
        ),
        MenuItem(
          key: 'toggle_guard',
          label: widget.languageNotifier.language == AppLanguage.vi
              ? 'Bật/Tắt bảo vệ'
              : widget.languageNotifier.language == AppLanguage.zh
                  ? '开启/关闭防护'
                  : 'Toggle Guard',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit_app',
          label: widget.languageNotifier.language == AppLanguage.vi
              ? 'Thoát'
              : widget.languageNotifier.language == AppLanguage.zh
                  ? '退出'
                  : 'Exit',
        ),
      ];
      await trayManager.setContextMenu(Menu(items: menuItems));
    } catch (e) {
      debugPrint('Tray init error: $e');
    }
  }

  @override
  void onWindowClose() async {
    final closeToTray =
        AppConfig.get('close_to_tray', defaultValue: 'false') == 'true';
    if (closeToTray) {
      await windowManager.hide();
    } else {
      if (mounted) {
        setState(() {
          _isClosing = true;
        });
      }
      await Future.delayed(const Duration(milliseconds: 100));
      await widget.logic.stopGuard();
      await windowManager.destroy();
    }
  }

  @override
  void onTrayIconMouseDown() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'toggle_guard') {
      await _toggleGuard();
    } else if (menuItem.key == 'exit_app') {
      final isVisible = await windowManager.isVisible();
      if (isVisible && mounted) {
        setState(() {
          _isClosing = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await widget.logic.stopGuard();
      await windowManager.destroy();
    }
  }

  void _onSearchChanged() {
    widget.logic.setSearchQuery(_searchController.text);
  }

  void _onLogicChange() {
    if (mounted) {
      final config = widget.logic.hotspotConfig;
      if (config != null) {
        if (_hotspotSsidController.text.isEmpty && config.ssid.isNotEmpty) {
          _hotspotSsidController.text = config.ssid;
        }
        if (_hotspotPasswordController.text.isEmpty &&
            config.passphrase.isNotEmpty) {
          _hotspotPasswordController.text = config.passphrase;
        }
        if (_hotspotMaxClientsController.text.isEmpty) {
          _hotspotMaxClientsController.text = config.maxClients.toString();
        }
      }
      setState(() {});
      if (_activeTab == 'CONSOLE' &&
          _autoScrollLogs &&
          _logScrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScrollController.hasClients) {
            _logScrollController
                .jumpTo(_logScrollController.position.maxScrollExtent);
          }
        });
      }
    }
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    await widget.logic.initialize();
    _isAdmin = await widget.logic.isAdmin();

    // Load preferences
    _startupWithWindows = await widget.logic.getIsStartupEnabled();
    _startMinimized =
        AppConfig.get('start_minimized', defaultValue: 'false') == 'true';
    _closeToTray =
        AppConfig.get('close_to_tray', defaultValue: 'false') == 'true';
    _autoStartGuard =
        AppConfig.get('auto_start_guard', defaultValue: 'false') == 'true';
    _autoStartHotspot =
        AppConfig.get('auto_start_hotspot', defaultValue: 'false') == 'true';

    if (_autoStartHotspot) {
      _autoStartHotspotProcedure();
    } else {
      // Auto-start guard if preference is enabled and hotspot auto-start is disabled
      if (_autoStartGuard && !widget.logic.isGuardActive) {
        await widget.logic.startGuard();
      }
    }

    // Initial scans
    await widget.logic.scanConnectedClients();
    await widget.logic.readLogLines();

    // Initialize hotspot fields
    final config = widget.logic.hotspotConfig;
    if (config != null) {
      _hotspotSsidController.text = config.ssid;
      _hotspotPasswordController.text = config.passphrase;
      _selectedHotspotBand = config.band;
      _hotspotMaxClientsController.text = config.maxClients.toString();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _autoStartHotspotProcedure() async {
    int retry = 0;
    bool hasProfile = false;

    // Wait up to 30 seconds for the Internet Connection Profile to become available.
    // This replicates the boot wait loop of Toggle_Hotspot.ps1.
    while (retry < 15) {
      final config = widget.logic.hotspotConfig;
      if (config != null &&
          config.ssid.isNotEmpty &&
          config.ssid != 'Offline / No Profile') {
        hasProfile = true;
        break;
      }
      await widget.logic.fetchHotspotConfig();
      await Future.delayed(const Duration(seconds: 2));
      retry++;
    }

    final config = widget.logic.hotspotConfig;
    if (config != null && config.state == 'Disabled' && hasProfile) {
      await widget.logic.resetSharedAccessService();

      await Future.delayed(const Duration(seconds: 1));

      // Start Hotspot
      await widget.logic.setHotspotState(true);
    }

    // Auto-start guard if preference is enabled after hotspot check completes
    if (_autoStartGuard && !widget.logic.isGuardActive) {
      await widget.logic.startGuard();
    }
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _toggleGuard() async {
    if (widget.logic.isGuardActive) {
      await widget.logic.stopGuard();
      _showSnackbar(_s.msgGuardInactive);
    } else {
      await widget.logic.startGuard();
      _showSnackbar(_s.msgGuardActive);
    }
  }

  Future<void> _addDevice() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AddDeviceDialog(logic: widget.logic),
    );
    if (result == true) {
      _showSnackbar(_s.msgAddSuccess);
    }
  }

  Future<void> _editNicknameInline(String mac, String nickname) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => EditNicknameDialog(
        currentMac: mac,
        currentNickname: nickname,
        logic: widget.logic,
      ),
    );
    if (result == true) {
      _showSnackbar('Nickname updated successfully');
      await widget.logic.scanConnectedClients();
    }
  }

  Future<void> _deleteDeviceInline(WhitelistEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteDeviceDialog(entry: entry),
    );

    if (confirm == true) {
      await widget.logic.removeWhitelistDevice(entry.mac);
      _showSnackbar(_s.msgRemoveSuccess);
      await widget.logic.scanConnectedClients();
    }
  }

  Future<void> _quickWhitelistClient(ClientDevice client) async {
    final success = await widget.logic.addWhitelistDevice(
      client.mac,
      client.nickname.isNotEmpty ? client.nickname : 'New Device',
    );
    if (success) {
      _showSnackbar(_s.msgAddSuccess);
      await widget.logic.scanConnectedClients();
    }
  }

  Future<void> _quickBlockClient(ClientDevice client) async {
    await widget.logic.removeWhitelistDevice(client.mac);
    _showSnackbar(_s.msgRemoveSuccess);
    await widget.logic.scanConnectedClients();
  }

  Future<void> _importWhitelist() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Whitelist',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      try {
        final res =
            await widget.logic.importWhitelist(result.files.single.path!);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => ImportResultsDialog(result: res),
        );
      } catch (e) {
        _showSnackbar('${_s.errImportFailed}: $e', isError: true);
      }
    }
  }

  Future<void> _exportWhitelist() async {
    final timestamp = formatTimestampFileName();
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Whitelist',
      fileName: 'ja_wifi_whitelist_$timestamp.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputFile != null) {
      final success = await widget.logic.exportWhitelist(outputFile);
      if (success) {
        _showSnackbar(_s.msgExportSuccess);
      }
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? _c.statusRemoved : _c.statusActive,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  ButtonStyle _iconBtnStyle() => IconButton.styleFrom(
        backgroundColor: _c.bgTertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: _c.borderDefault),
        ),
      );

  String get _themeModeLabel {
    switch (widget.themeNotifier.mode) {
      case AppThemeMode.dark:
        return _s.themeDark;
      case AppThemeMode.light:
        return _s.themeLight;
      case AppThemeMode.auto:
        return _s.themeAuto;
    }
  }

  // ─── Layout Builder ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isClosing) {
      return Container(
        color: _c.bgPrimary,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _c.statusRemoved),
                const SizedBox(height: 16),
                Text(
                  _s.msgClosingApp,
                  style: TextStyle(
                    color: _c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Container(
        color: _c.bgPrimary,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _c.linkAccent),
                const SizedBox(height: 16),
                Text(_s.msgProcessing,
                    style: TextStyle(color: _c.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _c.bgPrimary,
      body: Row(
        children: [
          Sidebar(
            logic: widget.logic,
            isAdmin: _isAdmin,
            activeTab: _activeTab,
            onTabSelected: (tab) => setState(() => _activeTab = tab),
            onToggleGuard: _toggleGuard,
          ),
          VerticalDivider(
              width: 1, color: _c.borderDefault.withValues(alpha: 0.08)),
          Expanded(
            child: Column(
              children: [
                _buildHeaderBar(),
                Divider(
                    height: 1, color: _c.borderDefault.withValues(alpha: 0.08)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildMainContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header Bar ───────────────────────────────────────────────────────────

  Widget _buildHeaderBar() {
    String tabTitle = 'Monitor';
    if (_activeTab == 'WHITELIST') tabTitle = 'Whitelist Manager';
    if (_activeTab == 'CONSOLE') tabTitle = 'Console Terminal';
    if (_activeTab == 'HOTSPOT') {
      tabTitle = widget.languageNotifier.language == AppLanguage.vi
          ? 'Cấu hình Hotspot'
          : widget.languageNotifier.language == AppLanguage.zh
              ? '热点配置'
              : 'Mobile Hotspot';
    }
    if (_activeTab == 'SETTINGS') tabTitle = 'Global Settings';
    final isTransparent = AppConfig.enableTransparency;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: isTransparent
          ? _c.bgSecondary.withValues(alpha: 0.1)
          : _c.bgSecondary,
      child: Row(
        children: [
          // Section Title
          Text(
            tabTitle,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _c.textPrimary),
          ),
          const Spacer(),

          // Search Box (only on Monitor & Whitelist tabs)
          if (_activeTab == 'MONITOR' || _activeTab == 'WHITELIST') ...[
            Container(
              width: 260,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              child: TextFormField(
                controller: _searchController,
                style: TextStyle(color: _c.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search MAC, IP...',
                  prefixIcon: Icon(Icons.search, size: 16, color: _c.textMuted),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            widget.logic.setSearchQuery('');
                          },
                          child:
                              Icon(Icons.clear, size: 16, color: _c.textMuted),
                        )
                      : null,
                  filled: true,
                  fillColor: _c.bgTertiary.withValues(alpha: 0.4),
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                        color: _c.borderDefault.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                        color: _c.linkAccent.withValues(alpha: 0.8),
                        width: 1.5),
                  ),
                ),
              ),
            ),
          ],

          // Refresh button
          if (_activeTab == 'MONITOR' || _activeTab == 'WHITELIST') ...[
            Tooltip(
              message: _s.tooltipRefresh,
              child: IconButton(
                onPressed: () async {
                  await widget.logic.scanConnectedClients();
                  await widget.logic.readLogLines();
                  _showSnackbar('Data Refreshed');
                },
                icon: Icon(Icons.refresh, color: _c.textSecondary, size: 18),
                style: _iconBtnStyle(),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Theme reveal toggle
          Tooltip(
            key: _themeButtonKey,
            message: _s.tooltipTheme(_themeModeLabel),
            child: IconButton(
              onPressed: () {
                final themeReveal =
                    context.findAncestorStateOfType<ThemeRevealState>();
                if (themeReveal != null) {
                  themeReveal.triggerReveal(
                    buttonKey: _themeButtonKey,
                    onToggle: () {
                      widget.themeNotifier
                          .toggle(MediaQuery.platformBrightnessOf(context));
                      setState(() {});
                    },
                  );
                } else {
                  widget.themeNotifier
                      .toggle(MediaQuery.platformBrightnessOf(context));
                  setState(() {});
                }
              },
              icon: Icon(widget.themeNotifier.modeIcon,
                  color: _c.linkAccent, size: 18),
              style: _iconBtnStyle(),
            ),
          ),
          const SizedBox(width: 8),

          // Language toggle
          Tooltip(
            message:
                '${_s.tooltipLanguage}: ${widget.languageNotifier.language.fullLabel}',
            child: InkWell(
              onTap: () {
                widget.languageNotifier.cycleNext();
                setState(() {});
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _c.bgTertiary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _c.borderDefault),
                ),
                child: Row(
                  children: [
                    Icon(Icons.language, size: 14, color: _c.linkAccent),
                    const SizedBox(width: 6),
                    Text(
                      widget.languageNotifier.language.shortLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _c.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Main Content Switches ────────────────────────────────────────────────

  Widget _buildMainContent() {
    switch (_activeTab) {
      case 'WHITELIST':
        return WhitelistTab(
          logic: widget.logic,
          onAddDevice: _addDevice,
          onEditNickname: _editNicknameInline,
          onDeleteDevice: _deleteDeviceInline,
        );
      case 'CONSOLE':
        return _buildConsoleTab();
      case 'HOTSPOT':
        return _buildHotspotTab();
      case 'SETTINGS':
        return _buildSettingsTab();
      case 'MONITOR':
      default:
        return MonitorTab(
          logic: widget.logic,
          hasSearchQuery: _searchController.text.isNotEmpty,
          onQuickBlock: _quickBlockClient,
          onQuickWhitelist: _quickWhitelistClient,
          onEditNickname: _editNicknameInline,
          onSnackbar: _showSnackbar,
        );
    }
  }
  // ─── CONSOLE TAB (Terminal view) ──────────────────────────────────────────

  Widget _buildConsoleTab() {
    final rawLogs = widget.logic.logLines;

    // Apply log levels filter
    final List<String> logs = [];
    for (final line in rawLogs) {
      if (_logLevelFilter == 'BLOCKS' && !line.contains('[BLOCK]')) continue;
      if (_logLevelFilter == 'WARNINGS' && !line.contains('[WARN]')) continue;
      logs.add(line);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls row
        Row(
          children: [
            // Filter dropdown
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _c.bgTertiary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _c.borderDefault),
              ),
              child: DropdownButton<String>(
                value: _logLevelFilter,
                underline: const SizedBox(),
                dropdownColor: _c.bgSecondary,
                style: TextStyle(
                    color: _c.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Events')),
                  DropdownMenuItem(value: 'BLOCKS', child: Text('Blocks Only')),
                  DropdownMenuItem(
                      value: 'WARNINGS', child: Text('Warnings Only')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _logLevelFilter = val);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),

            // Auto scroll checkbox
            Row(
              children: [
                Checkbox(
                  value: _autoScrollLogs,
                  onChanged: (val) =>
                      setState(() => _autoScrollLogs = val ?? true),
                ),
                Text(
                  'Auto Scroll',
                  style: TextStyle(
                      fontSize: 12,
                      color: _c.textSecondary,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),

            // Copy logs button
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: rawLogs.join('\n')));
                _showSnackbar('Logs copied to clipboard');
              },
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copy All'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),

            // Clear logs button
            OutlinedButton.icon(
              onPressed: () async {
                await widget.logic.clearLogs();
                _showSnackbar('Log Console Cleared');
              },
              icon: const Icon(Icons.cleaning_services, size: 14),
              label: const Text('Clear'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Terminal Screen
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            backgroundColor: _c.bgPrimary.withValues(alpha: 0.45),
            borderColor: _c.borderDefault.withValues(alpha: 0.15),
            child: ClipRect(
              child: ListView.builder(
                controller: _logScrollController,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  Color txtColor = _c.textSecondary;
                  if (log.contains('[BLOCK]')) {
                    txtColor = _c.statusRemoved;
                  } else if (log.contains('[ALLOW]')) {
                    txtColor = _c.statusActive;
                  } else if (log.contains('[WARN]')) {
                    txtColor = _c.statusChanged;
                  } else if (log.contains('[OK]')) {
                    txtColor = _c.statusActive;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'Cascadia Code',
                        fontSize: 12,
                        color: txtColor,
                        height: 1.4,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHotspotTab() {
    final c = _c;
    final lang = widget.languageNotifier.language;
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
        key: _hotspotFormKey,
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
                            _isHotspotLoading
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
                                      setState(() => _isHotspotLoading = true);
                                      final ok = await widget.logic
                                          .setHotspotState(val);
                                      setState(() => _isHotspotLoading = false);
                                      if (ok) {
                                        _showSnackbar(isVi
                                            ? 'Đã chuyển đổi trạng thái hotspot'
                                            : 'Hotspot state changed');
                                      } else {
                                        _showSnackbar(
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
                                  onTap: () {
                                    setState(() {
                                      _activeTab = 'MONITOR';
                                    });
                                  },
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
                                      _showSnackbar(isVi
                                          ? 'Đang sửa lỗi IP/DHCP Hotspot...'
                                          : 'Fixing Hotspot IP/DHCP...');
                                      final ok =
                                          await widget.logic.fixHotspotDhcp();
                                      setState(() => _isFixingDhcp = false);
                                      if (ok) {
                                        _showSnackbar(isVi
                                            ? 'Sửa lỗi thành công! Hãy bật lại Hotspot.'
                                            : 'Fix completed! Please enable Hotspot.');
                                      } else {
                                        _showSnackbar(
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
                              controller: _hotspotSsidController,
                              style:
                                  TextStyle(color: c.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.wifi, size: 16),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                      ? _s.errFillRequired
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
                              controller: _hotspotPasswordController,
                              obscureText: _obscureHotspotPassword,
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 13,
                                  fontFamily: _obscureHotspotPassword
                                      ? null
                                      : 'Cascadia Code'),
                              decoration: InputDecoration(
                                prefixIcon:
                                    const Icon(Icons.lock_outline, size: 16),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureHotspotPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 16,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscureHotspotPassword =
                                          !_obscureHotspotPassword),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return _s.errFillRequired;
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
                                value: _selectedHotspotBand,
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
                                    setState(() => _selectedHotspotBand = val);
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
                              controller: _hotspotMaxClientsController,
                              style:
                                  TextStyle(color: c.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                prefixIcon:
                                    Icon(Icons.people_alt_outlined, size: 16),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return _s.errFillRequired;
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
                      onPressed: _isHotspotLoading
                          ? null
                          : () async {
                              if (!_hotspotFormKey.currentState!.validate()) {
                                return;
                              }
                              setState(() => _isHotspotLoading = true);
                              _showSnackbar(msgUpdating);

                              final maxClientsVal = int.tryParse(
                                      _hotspotMaxClientsController.text
                                          .trim()) ??
                                  8;
                              final ok = await widget.logic.updateHotspotConfig(
                                _hotspotSsidController.text.trim(),
                                _hotspotPasswordController.text.trim(),
                                _selectedHotspotBand,
                                maxClientsVal,
                              );

                              setState(() => _isHotspotLoading = false);
                              if (ok) {
                                _showSnackbar(msgSuccess);
                                final newConfig = widget.logic.hotspotConfig;
                                if (newConfig != null) {
                                  _hotspotSsidController.text = newConfig.ssid;
                                  _hotspotPasswordController.text =
                                      newConfig.passphrase;
                                  _selectedHotspotBand = newConfig.band;
                                  _hotspotMaxClientsController.text =
                                      newConfig.maxClients.toString();
                                }
                              } else {
                                _showSnackbar(msgError, isError: true);
                              }
                            },
                      icon: _isHotspotLoading
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

  // ─── SETTINGS TAB (Unified Config & User Guide) ───────────────────────────

  Widget _buildSettingsTab() {
    final c = _c;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row of Transparency & Interval Card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System Preferences
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StyledWidgets.sectionHeader(_s.settingsSystemTitle, c,
                          icon: Icons.tune),
                      const SizedBox(height: 12),

                      // Auto Check Interval
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_s.settingsGuardInterval,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(_s.settingsGuardIntervalDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: c.bgTertiary,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: c.borderDefault),
                            ),
                            child: DropdownButton<int>(
                              value: widget.logic.checkIntervalSeconds,
                              underline: const SizedBox(),
                              dropdownColor: c.bgSecondary,
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                              items: [
                                DropdownMenuItem(
                                    value: 5, child: Text(_s.settingsSec5)),
                                DropdownMenuItem(
                                    value: 10, child: Text(_s.settingsSec10)),
                                DropdownMenuItem(
                                    value: 30, child: Text(_s.settingsSec30)),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  widget.logic.setCheckInterval(val);
                                  _showSnackbar(
                                      'Interval updated to $val seconds');
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      // Startup with Windows
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.power_settings_new_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_s.settingStartup,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(_s.settingStartupDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _startupWithWindows,
                            activeThumbColor: c.statusActive,
                            onChanged: (val) async {
                              await widget.logic.setStartupEnabled(val);
                              setState(() {
                                _startupWithWindows = val;
                              });
                              _showSnackbar(val
                                  ? 'Startup with Windows enabled'
                                  : 'Startup with Windows disabled');
                            },
                          ),
                        ],
                      ),

                      // Start Minimized to Tray
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.visibility_off_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_s.settingStartMinimized,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(_s.settingStartMinimizedDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _startMinimized,
                            activeThumbColor: c.statusActive,
                            onChanged: (val) async {
                              await AppConfig.set(
                                  'start_minimized', val.toString());
                              setState(() {
                                _startMinimized = val;
                              });
                              _showSnackbar(val
                                  ? 'Start minimized enabled'
                                  : 'Start minimized disabled');
                            },
                          ),
                        ],
                      ),

                      // Close to System Tray
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.close_fullscreen_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_s.settingCloseToTray,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(_s.settingCloseToTrayDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _closeToTray,
                            activeThumbColor: c.statusActive,
                            onChanged: (val) async {
                              await AppConfig.set(
                                  'close_to_tray', val.toString());
                              setState(() {
                                _closeToTray = val;
                              });
                              _showSnackbar(val
                                  ? 'Close to tray enabled'
                                  : 'Close to tray disabled');
                            },
                          ),
                        ],
                      ),

                      // Auto-start Guard on Launch
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_s.settingAutoStartGuard,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(_s.settingAutoStartGuardDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _autoStartGuard,
                            activeThumbColor: c.statusActive,
                            onChanged: (val) async {
                              await AppConfig.set(
                                  'auto_start_guard', val.toString());
                              setState(() {
                                _autoStartGuard = val;
                              });
                              _showSnackbar(val
                                  ? 'Auto-start guard enabled'
                                  : 'Auto-start guard disabled');
                            },
                          ),
                        ],
                      ),

                      // Auto-start Hotspot on Launch
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.wifi_tethering_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_s.settingAutoStartHotspot,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(_s.settingAutoStartHotspotDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _autoStartHotspot,
                            activeThumbColor: c.statusActive,
                            onChanged: (val) async {
                              await AppConfig.set(
                                  'auto_start_hotspot', val.toString());
                              setState(() {
                                _autoStartHotspot = val;
                              });
                              _showSnackbar(val
                                  ? 'Auto-start hotspot enabled'
                                  : 'Auto-start hotspot disabled');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Whitelist Backup Services
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StyledWidgets.sectionHeader(
                          'Whitelist Data Management', c,
                          icon: Icons.folder_zip_outlined),
                      const SizedBox(height: 16),
                      Text(
                        'Import or export your whitelisted MAC addresses database to back up your configurations.',
                        style: TextStyle(
                            fontSize: 12, color: c.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _importWhitelist,
                              icon: const Icon(Icons.file_open_outlined,
                                  size: 16),
                              label: const Text('Import Whitelist'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _exportWhitelist,
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Export Whitelist'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
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
          const SizedBox(height: 20),

          // User Guide Card
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: DefaultTabController(
              length: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StyledWidgets.sectionHeader('System Documentation & Guide', c,
                      icon: Icons.info_outline),
                  TabBar(
                    labelColor: c.linkAccent,
                    unselectedLabelColor: c.textMuted,
                    indicatorColor: c.linkAccent,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(text: _s.guideTabGeneral),
                      Tab(text: _s.guideTabSecurity),
                      Tab(text: _s.guideTabFAQ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 210,
                    child: TabBarView(
                      children: [
                        TabDocsSection(
                            title: _s.guideOverviewTitle,
                            body: _s.guideOverviewContent),
                        TabDocsSection(
                            title: _s.guideSecurityTitle,
                            body: _s.guideSecurityContent),
                        TabDocsSection(
                            title: _s.guideFAQTitle, body: _s.guideFAQContent),
                      ],
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
