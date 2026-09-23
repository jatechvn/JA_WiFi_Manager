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

  String get tabTitleMonitor => _s('Monitor', '实时监控', 'Giám sát');
  String get tabTitleWhitelist =>
      _s('Whitelist Manager', '白名单管理', 'Quản lý danh sách trắng');
  String get tabTitleConsole => _s('Console Terminal', '控制台', 'Bảng nhật ký');
  String get tabTitleHotspot =>
      _s('Mobile Hotspot', '热点配置', 'Cấu hình Hotspot');
  String get tabTitleSettings => _s('Global Settings', '全局设置', 'Cài đặt chung');

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
  String get tooltipClearSearch => _s('Clear search', '清除搜索', 'Xóa tìm kiếm');
  String get tooltipCardView => _s('Card View', '卡片视图', 'Xem thẻ');
  String get tooltipTableView => _s('Table View', '表格视图', 'Xem bảng');
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

  // ── LAN OTA Update ──────────────────────────
  String get otaTitle =>
      _s('LAN OTA Update', '局域网在线更新', 'Cập Nhật Mạng Nội Bộ (OTA)');
  String get otaDesc => _s(
      'Automatically check and update from internal network share or server',
      '自动检测局域网共享服务器或内部文件服务器上的最新版本',
      'Tự động kiểm tra và nâng cấp phiên bản từ máy chủ chia sẻ nội bộ');
  String get otaCurrentVersion =>
      _s('Current Version', '当前版本', 'Phiên bản hiện tại');
  String get otaLastChecked => _s('Last checked', '上次检查', 'Kiểm tra gần nhất');
  String get otaNeverChecked =>
      _s('Never checked', '从未检查', 'Chưa kiểm tra bao giờ');
  String get otaCheckNow =>
      _s('Check for Updates', '检查更新', 'Kiểm tra cập nhật');
  String get otaChecking => _s('Checking...', '正在检查...', 'Đang kiểm tra...');
  String get otaUpdateNow => _s('Update Now', '立即更新', 'Cập nhật ngay');
  String otaUpdateAvailable(String ver) => _s('New version $ver is available!',
      '发现新版本 $ver 可用！', 'Đã có phiên bản mới $ver!');
  String get otaUpToDate => _s('You are using the latest version.', '当前已是最新版本。',
      'Bạn đang sử dụng phiên bản mới nhất.');
  String get otaServerPath => _s('Server Share Path (UNC / Directory)',
      '服务器共享路径 (UNC/目录)', 'Đường dẫn máy chủ (UNC / Thư mục)');
  String get otaServerPathHint => _s(
      r'\\server\share\path', r'\\server\share\path', r'\\server\share\path');
  String get otaUsername => _s('SMB Username', 'SMB 用户名', 'Tài khoản SMB');
  String get otaPassword => _s('SMB Password', 'SMB 密码', 'Mật khẩu SMB');
  String get otaCheckInterval =>
      _s('Auto-check Frequency', '自动检查频率', 'Tần suất tự kiểm tra');
  String get otaIntervalDaily =>
      _s('Daily (24 hours)', '每天 (24小时)', 'Hàng ngày (24 giờ)');
  String get otaIntervalWeekly =>
      _s('Weekly (7 days)', '每周 (7天)', 'Hàng tuần (7 ngày)');
  String get otaIntervalMonthly =>
      _s('Monthly (30 days)', '每月 (30天)', 'Hàng tháng (30 ngày)');
  String get otaIntervalOff =>
      _s('Disabled (Manual only)', '关闭 (仅手动)', 'Tắt (Chỉ thủ công)');
  String get otaTestConnection => _s('Test SMB', '测试连接', 'Thử kết nối');
  String get otaTestingConnection => _s('Testing...', '正在连接...', 'Đang thử...');
  String get otaConnectionSuccess => _s('SMB share connected successfully!',
      'SMB 共享连接成功！', 'Kết nối thư mục chia sẻ thành công!');
  String get otaConnectionFailed => _s('Failed to connect to SMB share',
      '连接 SMB 共享失败', 'Kết nối thư mục chia sẻ thất bại');
  String get otaOpenConfigFolder =>
      _s('Open Config Folder', '打开配置目录', 'Mở thư mục cấu hình');
  String get otaSaveConfig =>
      _s('Save OTA Settings', '保存更新配置', 'Lưu cấu hình OTA');
  String get otaConfigSaved =>
      _s('OTA settings saved successfully', '更新配置保存成功', 'Đã lưu cấu hình OTA');
  String get otaConfigSaveFailed => _s('Could not save OTA settings securely',
      '无法安全保存 OTA 配置', 'Không thể lưu cấu hình OTA an toàn');
  String get otaReleaseNotes =>
      _s('Release Notes', '更新日志', 'Ghi chú phát hành');
  String get otaPackageSize => _s('Package Size', '文件大小', 'Kích thước gói');
  String get otaDownloading => _s('Downloading update package...', '正在下载更新包...',
      'Đang tải gói cập nhật...');
  String get otaExtracting => _s('Extracting update package...', '正在解压更新包...',
      'Đang giải nén gói cập nhật...');
  String get otaApplying => _s('Applying update and restarting...',
      '正在应用更新并重启...', 'Đang áp dụng cập nhật và khởi động lại...');

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

  // ── Console ──────────────────────────────────
  String get consoleTitle => _s(
        'JA WiFi Guard Console • live_stream.log',
        'JA WiFi Guard Console • live_stream.log',
        'JA WiFi Guard Console • live_stream.log',
      );
  String get consoleStreamActive => _s('STREAM ACTIVE', '正在接收', 'ĐANG NHẬN');
  String get consoleSearchHint =>
      _s('Search logs...', '搜索日志...', 'Tìm từ khóa trong log...');
  String get consoleFilterAll => _s('All', '全部', 'Tất cả');
  String get consoleFilterBlocks => _s('Blocks', '拦截', 'Chặn');
  String get consoleFilterWarnings => _s('Warnings', '警告', 'Cảnh báo');
  String get consoleFilterAllows => _s('Allows', '允许', 'Cho phép');
  String get consoleAutoScroll => _s('Auto Scroll', '自动滚动', 'Tự cuộn');
  String get consoleCopy => _s('Copy', '复制', 'Sao chép');
  String get consoleClear => _s('Clear', '清除', 'Xóa');
  String get consoleCopied => _s(
        'Copied all logs to the clipboard',
        '已复制全部日志到剪贴板',
        'Đã sao chép toàn bộ logs vào clipboard',
      );
  String get consoleCleared => _s(
        'Cleared the terminal',
        '已清空终端画面',
        'Đã xóa sạch màn hình terminal',
      );
  String get consoleEmpty => _s(
        'No log lines match the current filter',
        '没有符合筛选条件的日志',
        'Không có bản ghi log nào phù hợp với bộ lọc',
      );

  // ── Settings extras ──────────────────────────
  String settingsIntervalUpdated(int seconds) => _s(
        'Scan interval updated: $seconds seconds',
        '检测周期已更新：$seconds 秒',
        'Chu kỳ quét đã cập nhật: $seconds giây',
      );
  String get settingsBackupTitle =>
      _s('Whitelist Backup', '白名单备份', 'Sao lưu Whitelist');
  String get settingsBackupDesc => _s(
        'Import or export the trusted MAC database to back up and sync between machines.',
        '导入或导出已信任的 MAC 地址库，以便备份并在多台电脑之间同步。',
        'Xuất hoặc nhập cơ sở dữ liệu các địa chỉ MAC đã tin cậy để sao lưu và đồng bộ giữa các máy trạm.',
      );
  String get settingsImportFile => _s('Import File', '导入文件', 'Nhập file');
  String get settingsExportFile => _s('Export File', '导出文件', 'Xuất file');
  String get settingsGuideTitle =>
      _s('Guide & Help', '帮助文档', 'Tài liệu hướng dẫn & Trợ giúp');
  String get otaCheckIntervalDesc => _s(
        'How often to look for a new release when the app opens',
        '打开应用时自动检查新版本的频率',
        'Tần suất tự động kiểm tra bản phát hành mới khi mở ứng dụng',
      );

  // ── Hotspot ──────────────────────────────────
  String get hotspotConfigTitle => _s(
        'Wi-Fi Network Configuration',
        '无线网络配置',
        'Cấu hình mạng Wi-Fi',
      );
  String get hotspotSsidLabel =>
      _s('Network Name (SSID)', '网络名称 (SSID)', 'Tên Wi-Fi (SSID)');
  String get hotspotPasswordLabel =>
      _s('Network Password (WPA2)', '网络密码 (WPA2)', 'Mật khẩu Wi-Fi');
  String get hotspotBandLabel => _s('Network Band', '网络频段', 'Băng tần');
  String get hotspotSave => _s('Save Configuration', '保存设置', 'Lưu cấu hình');
  String get hotspotUpdating => _s(
        'Updating hotspot settings...',
        '正在更新配置...',
        'Đang cập nhật cấu hình...',
      );
  String get hotspotUpdated => _s(
        'Hotspot settings updated successfully!',
        '热点配置更新成功!',
        'Đã cập nhật cấu hình hotspot!',
      );
  String get hotspotUpdateFailed =>
      _s('Failed to update settings!', '更新失败!', 'Cập nhật thất bại!');
  String get hotspotNote => _s(
        'Note: This feature configures the default Windows Mobile Hotspot. You can change the maximum client limit (default is 8, requires Administrator permissions, and may require toggling the Hotspot to apply).',
        '注意: 此功能将直接修改 Windows 默认的移动热点配置。您可以修改最大连接数限制（默认为 8，需管理员权限，可能需要重新开关热点生效）。',
        'Lưu ý: Tính năng này thay đổi trực tiếp cấu hình Mobile Hotspot mặc định của Windows. Bạn có thể thay đổi giới hạn số thiết bị tối đa (mặc định là 8, yêu cầu quyền Administrator và có thể cần bật/tắt lại Hotspot).',
      );
  String get hotspotMaxClients => _s(
        'Max Clients Limit (1-128)',
        '连接限制数 (1-128)',
        'Giới hạn kết nối (1-128)',
      );
  String get hotspotLoading => _s(
        'Loading Hotspot configurations...',
        '正在获取热点配置...',
        'Đang tải thông tin Hotspot...',
      );
  String get hotspotDefaultName => _s(
        'Windows Mobile Hotspot',
        'Windows 移动热点',
        'Windows Mobile Hotspot',
      );
  String get hotspotBroadcasting => _s(
        'Broadcasting Wi-Fi network and sharing Internet',
        '正在广播 Wi-Fi 并共享 Internet',
        'Đang phát sóng Wi-Fi và chia sẻ kết nối Internet',
      );
  String get hotspotStoppedHint => _s(
        'Mobile Hotspot is off. Toggle to start sharing.',
        '移动热点已关闭。打开开关即可开始共享。',
        'Điểm phát sóng đang tắt. Bật công tắc để bắt đầu chia sẻ.',
      );
  String get hotspotToggled => _s(
        'Hotspot state changed',
        '热点状态已切换',
        'Đã chuyển đổi trạng thái hotspot',
      );
  String get hotspotToggleFailed =>
      _s('Failed to toggle hotspot!', '切换热点失败!', 'Chuyển đổi thất bại!');
  String get hotspotIcsWorking => _s(
        'Killing ICS PID & restarting SharedAccess...',
        '正在结束 ICS 进程并重启 SharedAccess...',
        'Đang buộc dừng PID và khởi động lại dịch vụ ICS...',
      );
  String get hotspotIcsOk => _s(
        'ICS service repaired & restarted successfully!',
        'ICS 服务已成功重启!',
        'Dịch vụ ICS đã khởi động lại thành công!',
      );
  String get hotspotIcsFailed => _s(
        'Failed to restart ICS service!',
        '重启 ICS 服务失败!',
        'Khởi động lại dịch vụ ICS thất bại!',
      );
  String get hotspotFixIcs =>
      _s('Fix ICS (Kill PID)', '修复 ICS (结束进程)', 'Sửa lỗi ICS (Kill PID)');
  String get hotspotDhcpWorking => _s(
        'Fixing Hotspot IP/DHCP...',
        '正在修复热点 IP/DHCP...',
        'Đang sửa lỗi IP/DHCP Hotspot...',
      );
  String get hotspotDhcpOk => _s(
        'Fix completed! Please enable Hotspot.',
        '修复完成! 请重新打开热点。',
        'Sửa lỗi thành công! Hãy bật lại Hotspot.',
      );
  String get hotspotDhcpFailed =>
      _s('Failed to fix connection!', '修复连接失败!', 'Sửa lỗi thất bại!');
  String get hotspotFixDhcp => _s('Fix DHCP', '修复 IP/DHCP', 'Sửa IP/DHCP');
  String get hotspotOpenMonitor => _s(
        'Manage in Monitor Tab →',
        '在监控页管理设备 →',
        'Quản lý thiết bị ở Monitor →',
      );
  String get hotspotDhcpClients =>
      _s('DHCP Clients', 'DHCP 客户端', 'Máy khách DHCP');
  String get hotspotLeases =>
      _s('Allocated leases', '已分配地址', 'Đang cấp phát IP');
  String get hotspotArpTitle =>
      _s('Active Scan (ARP)', '实时扫描 (ARP)', 'Quét thực tế (ARP)');
  String get hotspotReachable =>
      _s('Reachable devices', '可达设备', 'Thiết bị đang truyền tin');
  String get hotspotBandTitle => _s('Wi-Fi Band', 'Wi-Fi 频段', 'Băng tần Wi-Fi');
  String get hotspotBandFreq =>
      _s('Operating frequency', '工作频率', 'Tần số phát sóng');
  String get hotspotSsidHint =>
      _s('Enter the Wi-Fi name...', '输入 Wi-Fi 名称...', 'Nhập tên Wi-Fi...');
  String get hotspotPasswordCopied => _s(
        'Wi-Fi password copied',
        '已复制 Wi-Fi 密码',
        'Đã sao chép mật khẩu Wi-Fi',
      );
  String get hotspotPasswordShort => _s(
        'Password must be at least 8 characters',
        '密码至少 8 个字符',
        'Mật khẩu phải từ 8 ký tự trở lên',
      );
  String get hotspotNotNumber =>
      _s('Must be a number', '必须是数字', 'Phải là chữ số');
  String get hotspotClientRange => _s(
        'Must be between 1 and 128',
        '限制范围为 1 到 128',
        'Giới hạn từ 1 đến 128',
      );
  String get hotspotSystemNote => _s('System Note', '系统说明', 'Ghi chú hệ thống');

  // ── Whitelist tab ────────────────────────────
  String get whitelistTrusted =>
      _s('Trusted Whitelist', '信任白名单', 'Thiết bị tin cậy');
  String get whitelistTrustedDesc =>
      _s('Approved for access', '已授权连接设备', 'Được cấp quyền truy cập');
  String get whitelistSecureBadge => _s('SECURE', '安全', 'SECURE');
  String get whitelistOnlineStat => _s('Active Online', '当前在线', 'Đang kết nối');
  String get whitelistOnlineStatDesc => _s(
        'Currently connected',
        '正在网络中传输',
        'Đang nhận diện trên mạng',
      );
  String get whitelistActiveBadge => _s('ACTIVE', '活跃', 'ACTIVE');
  String get whitelistIdleBadge => _s('IDLE', '空闲', 'IDLE');
  String get whitelistOfflineStat =>
      _s('Offline Devices', '离线设备', 'Ngoại tuyến');
  String get whitelistOfflineStatDesc => _s(
        'Not currently active',
        '暂未接入热点',
        'Chưa kết nối vào mạng',
      );
  String get whitelistStandbyBadge => _s('STANDBY', '待命', 'STANDBY');
  String get whitelistSearchHint => _s(
        'Search by nickname or MAC...',
        '搜索设备名称或MAC...',
        'Tìm theo tên hoặc MAC...',
      );
  String get whitelistFilterAll => _s('All', '全部', 'Tất cả');
  String get whitelistFilterOnline => _s('Online', '在线', 'Online');
  String get whitelistFilterOffline => _s('Offline', '离线', 'Offline');
  String get whitelistEmptyHint => _s(
        'Click "+ Add Device" or approve active devices from the Monitor tab.',
        '点击“+ 添加设备”，或在监控页批准正在连接的设备。',
        'Hãy nhấn "+ Thêm thiết bị" hoặc duyệt các thiết bị đang kết nối từ tab Monitor.',
      );
  String get whitelistUnnamed =>
      _s('Unnamed device', '未命名设备', 'Thiết bị không tên');
  String get whitelistConnectedNow => _s(
        'Connected to Hotspot',
        '已连接到热点',
        'Đang kết nối vào Wi-Fi',
      );
  String get whitelistDeviceOffline =>
      _s('Device is offline', '设备已离线', 'Thiết bị ngoại tuyến');
  String whitelistMacCopied(String mac) => _s(
        'Copied MAC: $mac',
        '已复制 MAC: $mac',
        'Đã sao chép MAC: $mac',
      );
  String get whitelistOnlineBadge => _s('ONLINE', '在线', 'ONLINE');
  String get whitelistOfflineBadge => _s('OFFLINE', '离线', 'OFFLINE');
  String get whitelistEditName => _s('Edit name', '修改名称', 'Sửa tên');
  String get whitelistRemoveDevice =>
      _s('Remove device', '移出列表', 'Xóa khỏi danh sách');

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
