// lib/modules/ui/main_window.dart
// Main visual dashboard window widget for JA WiFi Hotspot Guard (Fluent Refactored layout)

import 'dart:async';
import 'package:flutter/material.dart';
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
import 'header_bar.dart';
import 'console_tab.dart';
import 'hotspot_tab.dart';
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
                HeaderBar(
                  logic: widget.logic,
                  themeNotifier: widget.themeNotifier,
                  activeTab: _activeTab,
                  searchController: _searchController,
                  themeButtonKey: _themeButtonKey,
                  onDataRefreshed: () => _showSnackbar('Data Refreshed'),
                ),
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
        return ConsoleTab(
          logic: widget.logic,
          logScrollController: _logScrollController,
          logLevelFilter: _logLevelFilter,
          onLogLevelFilterChanged: (val) =>
              setState(() => _logLevelFilter = val),
          autoScrollLogs: _autoScrollLogs,
          onAutoScrollChanged: (val) => setState(() => _autoScrollLogs = val),
          onSnackbar: _showSnackbar,
        );
      case 'HOTSPOT':
        return HotspotTab(
          logic: widget.logic,
          onSnackbar: _showSnackbar,
          onNavigateToTab: (tab) => setState(() => _activeTab = tab),
        );
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
