// lib/modules/i18n.dart
// Multi-language support for JA WiFi Hotspot Guard (English / 中文 / Tiếng Việt)
// Uses InheritedNotifier for context-based access from anywhere in the tree

import 'package:flutter/material.dart';
import 'app_config.dart';

enum AppLanguage { en, zh, vi }

extension AppLanguageExt on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.en:
        return 'en';
      case AppLanguage.zh:
        return 'zh';
      case AppLanguage.vi:
        return 'vi';
    }
  }

  /// Short label displayed on the Globe button
  String get shortLabel {
    switch (this) {
      case AppLanguage.en:
        return 'EN';
      case AppLanguage.zh:
        return '中';
      case AppLanguage.vi:
        return 'VN';
    }
  }

  String get fullLabel {
    switch (this) {
      case AppLanguage.en:
        return 'English';
      case AppLanguage.zh:
        return '中文';
      case AppLanguage.vi:
        return 'Tiếng Việt';
    }
  }

  static AppLanguage fromCode(String code) {
    switch (code) {
      case 'zh':
        return AppLanguage.zh;
      case 'vi':
        return AppLanguage.vi;
      default:
        return AppLanguage.en;
    }
  }

  AppLanguage get next {
    final values = AppLanguage.values;
    return values[(index + 1) % values.length];
  }
}

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  // ── Action Bar & Filters ─────────────────────
  String get tabMonitor => _s('MONITOR', '实时监控', 'GIÁM SÁT');
  String get tabWhitelist => _s('WHITELIST', '白名单', 'DANH SÁCH TRẮNG');
  String get tabLogs => _s('LOGS', '日志', 'NHẬT KÝ');

  String get btnStartGuard => _s('Start Guard', '开启防护', 'Bật Bảo Vệ');
  String get btnStopGuard => _s('Stop Guard', '停止防护', 'Tắt Bảo Vệ');
  String get btnAddDevice => _s('Add Device', '添加设备', 'Thêm Thiết Bị');
  String get btnRefresh => _s('Refresh', '刷新', 'Làm mới');
  String get btnMore => _s('Advanced', '高级', 'Nâng cao');
  String get btnClose => _s('Close', '关闭', 'Đóng');
  String get btnCancel => _s('Cancel', '取消', 'Hủy');
  String get btnSave => _s('Save', '保存', 'Lưu');
  String get btnDelete => _s('Delete', '删除', 'Xóa');

  String get menuImport => _s('Import Whitelist', '导入白名单', 'Nhập danh sách');
  String get menuExport => _s('Export Whitelist', '导出白名单', 'Xuất danh sách');
  String get menuClearLogs => _s('Clear Logs', '清空日志', 'Xóa nhật ký');
  String get menuGuide => _s('User Guide', '用户指南', 'Hướng dẫn');

  String get tooltipRefresh => _s('Refresh lists', '刷新列表', 'Làm mới danh sách');
  String get tooltipLanguage => _s('Language', '语言', 'Ngôn ngữ');
  String tooltipTheme(String modeName) =>
      _s('Theme: $modeName', '主题: $modeName', 'Giao diện: $modeName');

  String get themeDark => _s('Dark', '深色', 'Tối');
  String get themeLight => _s('Light', '浅色', 'Sáng');
  String get themeAuto => _s('Auto', '自动', 'Tự động');

  // ── System Settings & Preferences ─────────────
  String get settingsSystemTitle =>
      _s('System Configurations', '系统配置', 'Cấu hình hệ thống');
  String get settingsGuardInterval =>
      _s('Guard Polling Frequency', '检测频率', 'Tần suất quét bảo vệ');
  String get settingsGuardIntervalDesc => _s(
      'How often the engine checks neighbors',
      '后台扫描检测客户端的时间间隔',
      'Tần suất động cơ quét kiểm tra thiết bị kết nối');
  String get settingsSec5 =>
      _s('5 Seconds (Default)', '5 秒 (默认)', '5 Giây (Mặc định)');
  String get settingsSec10 => _s('10 Seconds', '10 秒', '10 Giây');
  String get settingsSec30 => _s('30 Seconds', '30 秒', '30 Giây');

  String get settingStartup =>
      _s('Startup with Windows', '开机自启动', 'Khởi động cùng Windows');
  String get settingStartupDesc => _s(
      'Automatically start application when Windows boots',
      'Windows 启动时自动运行程序',
      'Tự động mở ứng dụng khi khởi động máy tính');
  String get settingStartMinimized => _s('Start Minimized to System Tray',
      '启动时最小化至系统托盘', 'Khởi động thu nhỏ ở khay hệ thống');
  String get settingStartMinimizedDesc => _s(
      'Launch hidden to system tray on startup',
      '启动时隐藏并显示在系统托盘中',
      'Chạy ẩn dưới khay hệ thống khi khởi động');
  String get settingCloseToTray =>
      _s('Close to System Tray', '关闭窗口至系统托盘', 'Đóng về khay hệ thống');
  String get settingCloseToTrayDesc => _s(
      'Keep running in the background when closed',
      'Nhấn đóng sẽ thu nhỏ xuống khay hệ thống thay vì thoát',
      'Thu nhỏ xuống khay hệ thống thay vì thoát hoàn toàn khi đóng');
  String get settingAutoStartGuard => _s('Auto-start Guard on Launch',
      '启动时自动开启防护', 'Tự động kích hoạt Bảo vệ khi chạy');
  String get settingAutoStartGuardDesc => _s(
      'Automatically activate guard monitoring when app opens',
      '启动程序时自动激活热点防入侵监控',
      'Tự động kích hoạt tính năng kiểm soát khi mở ứng dụng');
  String get settingAutoStartHotspot => _s('Auto-start Hotspot on Launch',
      '启动时自动开启移动热点', 'Tự động bật Hotspot khi chạy');
  String get settingAutoStartHotspotDesc => _s(
      'Automatically turn on Mobile Hotspot when the app starts',
      '打开应用时自动开启并配置移动热点',
      'Tự động kích hoạt điểm phát sóng Wi-Fi khi mở ứng dụng');

  // ── Table Headers ───────────────────────────
  String get colNum => '#';
  String get colIpAddress => _s('IP ADDRESS', 'IP 地址', 'ĐỊA CHỈ IP');
  String get colMacAddress => _s('MAC ADDRESS', 'MAC 地址', 'ĐỊA CHỈ MAC');
  String get colNickname => _s('DEVICE NICKNAME', '设备备注', 'TÊN THIẾT BỊ');
  String get colStatus => _s('STATUS', '状态', 'TRẠNG THÁI');
  String get colLastSeen => _s('LAST SEEN', '最后在线', 'LẦN CUỐI THẤY');
  String get colActions => _s('ACTIONS', '操作', 'HÀNH ĐỘNG');

  // ── Status Badges & State ──────────────────
  String get statusAllowed => _s('ALLOWED', '已允许', 'CHO PHÉP');
  String get statusBlocked => _s('BLOCKED', '已拦截', 'BỊ CHẶN');
  String get statusUnknown => _s('UNKNOWN', '待查', 'CHƯA BIẾT');
  String get labelAdmin => _s('Admin', '管理员', 'Quản trị');
  String get labelStandard => _s('Standard', '普通用户', 'Thường');

  // ── Empty States ────────────────────────────
  String get emptyConnected => _s('No active connections found', '暂无连接中的客户端',
      'Không có thiết bị nào đang kết nối');
  String get emptyWhitelist => _s(
      'Whitelist is empty. Add a MAC to get started.',
      '白名单为空。请添加设备。',
      'Danh sách trắng trống. Hãy thêm MAC để bắt đầu.');

  // ── Status Messages ─────────────────────────
  String get msgGuardStarting => _s(
      'Starting WiFi Guard...', '正在启动 WiFi 防护...', 'Đang bật bảo vệ WiFi...');
  String get msgGuardStopping => _s('Stopping Guard & cleaning blocks...',
      '正在停止防护并清理拦截...', 'Đang tắt bảo vệ và dọn dẹp...');
  String get msgGuardActive => _s('WiFi Hotspot Guard is active.',
      'WiFi 热点防护运行中。', 'Bảo vệ WiFi Hotspot đang hoạt động.');
  String get msgGuardInactive => _s(
      'Guard is inactive. Hotspot is unprotected.',
      '防护已关闭。热点未受保护。',
      'Bảo vệ đang tắt. Hotspot không được bảo vệ.');
  String get msgProcessing => _s('Processing...', '处理中...', 'Đang xử lý...');
  String get msgClosingApp => _s(
      'Closing application... Cleaning up firewall rules and network settings.',
      '正在关闭应用... 正在清理防火墙规则和网络设置。',
      'Đang đóng ứng dụng... Đang dọn dẹp các quy tắc tường lửa và thiết lập mạng.');

  String clientSummary(int total, int allowed, int blocked) => _s(
      'Total: $total | Allowed: $allowed | Blocked: $blocked',
      '总连接: $total | 已允许: $allowed | 已拦截: $blocked',
      'Tổng kết nối: $total | Cho phép: $allowed | Đang chặn: $blocked');

  String whitelistCount(int n) => _s('$n whitelisted devices', '$n 个白名单设备',
      '$n thiết bị trong danh sách trắng');

  // ── Dialogs & Forms ─────────────────────────
  String get dlgAddTitle =>
      _s('Add Whitelist Device', '添加白名单设备', 'Thêm Thiết Bị Whitelist');
  String get dlgEditTitle =>
      _s('Edit Device Nickname', '修改设备备注', 'Sửa Tên Thiết Bị');
  String get labelMac => _s('MAC Address', 'MAC 地址', 'Địa chỉ MAC');
  String get labelNickname =>
      _s('Device Nickname', '设备备注 (别名)', 'Tên thiết bị (Gợi nhớ)');
  String get hintMac => 'e.g. D0-65-78-C4-00-9F';
  String get hintNickname => 'e.g. My Phone, Mother\'s Laptop';

  String get errInvalidMac => _s('Invalid MAC format (XX-XX-XX-XX-XX-XX)',
      'MAC 地址格式不正确', 'Định dạng MAC không hợp lệ (XX-XX-XX-XX-XX-XX)');
  String get errMacExists => _s('This MAC address is already whitelisted',
      '此 MAC 地址已存在于白名单中', 'Địa chỉ MAC này đã có trong whitelist');
  String get errFillRequired => _s('Please fill in all required fields',
      '请填写所有必填字段', 'Vui lòng điền đầy đủ thông tin');

  String get dlgDeleteTitle => _s('Remove Device', '移除设备', 'Xóa Thiết Bị');
  String dlgDeleteConfirm(String name) => _s(
      'Are you sure you want to remove "$name" from whitelist?',
      '确定要从白名单中删除设备 "$name" 吗？',
      'Bạn có chắc chắn muốn xóa "$name" khỏi whitelist?');

  String get dlgImportTitle => _s('Import Results', '导入结果', 'Kết quả nhập');
  String importSummary(int added, int skipped, int failed) => _s(
      'Import completed:\n- $added added\n- $skipped skipped (duplicates)\n- $failed failed',
      '导入完成:\n- 成功导入 $added 个\n- 跳过 $skipped 个重复\n- 失败 $failed 个',
      'Nhập hoàn tất:\n- Đã thêm $added\n- Bỏ qua $skipped (đã có)\n- Thất bại $failed');

  String get msgExportSuccess => _s('Whitelist exported successfully',
      '白名单导出成功', 'Xuất danh sách trắng thành công');
  String get msgImportSuccess => _s('Whitelist imported successfully',
      '白名单导入 thành công', 'Nhập danh sách trắng thành công');
  String get errImportFailed => _s(
      'Failed to import whitelist', '导入白名单失败', 'Nhập danh sách trắng thất bại');

  String get msgAddSuccess => _s('Device added to whitelist', '设备已成功加入白名单',
      'Đã thêm thiết bị vào whitelist');
  String get msgRemoveSuccess => _s('Device removed from whitelist',
      '设备已从白名单移除', 'Đã xóa thiết bị khỏi whitelist');
  String get btnNickname => _s('Nickname', '修改备注', 'Sửa Tên');

  // ── User Guide ──────────────────────────────
  String get dlgGuideTitle => _s('JA WiFi Hotspot Guard - User Guide',
      'JA WiFi 热点防护 - 用户指南', 'JA WiFi Hotspot Guard - Hướng Dẫn');
  String get guideTabGeneral => _s('Overview', '概述', 'Tổng quan');
  String get guideTabSecurity => _s('Security', '安全机制', 'Cơ chế bảo vệ');
  String get guideTabFAQ => _s('Troubleshoot', '故障排除', 'Khắc phục sự cố');

  String get guideOverviewTitle =>
      _s('Overview & Purpose', '概述与用途', 'Tổng quan & Mục đích');
  String get guideOverviewContent => _s(
      'JA WiFi Hotspot Guard is designed to secure your Windows Mobile Hotspot. By default, anyone with your WiFi password can connect. This app monitors connected clients every 5 seconds and automatically blocks any device whose MAC address is not registered in your Whitelist.\n\nNote: Creating firewall rules and rewriting ARP entries requires administrative system rights, which is why the app escalates to Admin on start.',
      'JA WiFi 热点防护用于保护您的 Windows 移动热点安全。默认情况下，拥有 WiFi 密码的任何人都可以连接。此应用每 5 秒扫描一次连接客户端，并自动阻止未在白名单中注册的任何设备的网络访问。\n\n提示：创建防火墙规则和覆盖 ARP 需要系统管理员权限，因此本应用启动时会自动请求管理员身份。',
      'JA WiFi Hotspot Guard giúp bảo vệ điểm phát sóng Mobile Hotspot trên Windows của bạn. Mặc định, ai có mật khẩu WiFi đều có thể kết nối. Ứng dụng này giám sát các thiết bị kết nối mỗi 5 giây và tự động chặn truy cập internet của bất kỳ thiết bị nào có địa chỉ MAC không nằm trong Danh Sách Trắng.\n\nLưu ý: Việc tạo quy tắc firewall và can thiệp ARP yêu cầu quyền quản trị hệ thống, đó là lý do ứng dụng sẽ tự động yêu cầu quyền Administrator khi chạy.');

  String get guideSecurityTitle =>
      _s('Dual-Layer Blocking Mechanism', '双重拦截机制', 'Cơ chế chặn 2 lớp');
  String get guideSecurityContent => _s(
      'To guarantee that intruder devices cannot send or receive any network packets, the guard implements a dual-layer blockade:\n\n'
          '1. ARP POISONING (Layer 2): The app binds the intruder\'s IP address to a fake MAC address (00-00-00-00-00-01) permanently in the Windows ARP cache. Windows will fail to send Ethernet frames to the device.\n\n'
          '2. FIREWALL RULE (Layer 3): An Inbound Firewall block rule is added for the remote IP on the hotspot network interface, rejecting all incoming packets from the intruder.',
      '为保证被拦截设备无法发送或接收任何数据包，本防护程序实施双重阻断：\n\n'
          '1. ARP 双重欺骗（第二层）：程序在 Windows ARP 缓存中将入侵者的 IP 永久绑定到一个虚假 MAC 地址 (00-00-00-00-00-01)。Windows 将无法向该设备发送以太网帧。\n\n'
          '2. 防火墙拦截（第三层）：在热点网络接口上针对该 IP 添加一条入站防火墙阻止规则，拒绝来自入侵者的所有传入数据包。',
      'Để đảm bảo thiết bị lạ không thể gửi hay nhận dữ liệu qua mạng, chương trình thực hiện chặn ở cả 2 lớp:\n\n'
          '1. ARP POISONING (Lớp 2): Ứng dụng liên kết IP của thiết bị lạ với một địa chỉ MAC giả (00-00-00-00-00-01) vĩnh viễn trong bộ nhớ đệm ARP của Windows. Windows sẽ không thể gửi các gói tin L2 tới thiết bị đó.\n\n'
          '2. FIREWALL RULE (Lớp 3): Một quy tắc chặn Firewall Inbound được thêm vào cho IP đó trên card mạng Hotspot, từ chối mọi gói tin gửi đến từ thiết bị lạ.');

  String get guideFAQTitle =>
      _s('Troubleshooting', '常见故障与解决', 'Khắc phục sự cố');
  String get guideFAQContent => _s(
      '• Q: Why is a whitelisted device still blocked?\n'
          '  A: The device might have changed its IP or reconnected. The guard will resolve and unblock it automatically in the next check loop (within 5 seconds).\n\n'
          '• Q: What happens when the app exits?\n'
          '  A: When the guard is stopped or the app is closed, it cleans up all firewall rules starting with "WiFiGuard_" and flushes temporary ARP bindings, returning your network back to normal instantly.',
      '• 问：为什么白名单中的设备仍然无法上网？\n'
          '  答：设备可能更改了 IP 地址或重新连接了。防护程序会在下一个检查循环中（5秒内）自动识别并解封它。\n\n'
          '• 问：应用退出时会发生什么？\n'
          '  答：当防护关闭或应用退出时，它会自动清除所有以 "WiFiGuard_" 开头的防火墙规则，并刷新临时 ARP 绑定，立即恢复网络至正常状态。',
      '• H: Tại sao thiết bị trong whitelist vẫn bị chặn?\n'
          '  TL: Thiết bị đó có thể đã thay đổi IP hoặc kết nối lại. Trình bảo vệ sẽ tự động phát hiện và mở chặn trong vòng lặp tiếp theo (dưới 5 giây).\n\n'
          '• H: Điều gì xảy ra khi tắt ứng dụng?\n'
          '  TL: Khi tắt bảo vệ hoặc đóng ứng dụng, chương trình sẽ tự động dọn dẹp mọi quy tắc firewall bắt đầu bằng "WiFiGuard_" và xóa các cấu hình ARP tạm thời, trả mạng của bạn về trạng thái bình thường ngay lập tức.');

  String _s(String en, String zh, String vi) {
    switch (lang) {
      case AppLanguage.en:
        return en;
      case AppLanguage.zh:
        return zh;
      case AppLanguage.vi:
        return vi;
    }
  }
}

class LanguageNotifier extends ChangeNotifier {
  AppLanguage _lang;

  LanguageNotifier(this._lang);

  AppLanguage get language => _lang;
  AppStrings get strings => AppStrings(_lang);

  void setLanguage(AppLanguage lang) {
    if (_lang == lang) return;
    _lang = lang;
    AppConfig.set('language', lang.code);
    notifyListeners();
  }

  void cycleNext() => setLanguage(_lang.next);
}

class LanguageProvider extends InheritedNotifier<LanguageNotifier> {
  const LanguageProvider({
    super.key,
    required super.notifier,
    required super.child,
  });

  static LanguageNotifier of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<LanguageProvider>();
    assert(provider != null, 'No LanguageProvider found above this context');
    return provider!.notifier!;
  }
}

extension BuildContextI18n on BuildContext {
  AppStrings get strings => LanguageProvider.of(this).strings;
  LanguageNotifier get languageNotifier => LanguageProvider.of(this);
}
