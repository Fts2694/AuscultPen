import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';

/// 设置页
/// 分组列表布局：AI 服务配置 / 多媒体配置 / 数据管理 / 关于
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final AiService _aiService = AiService();
  bool _testingConnection = false;

  // ==================== API Key 对话框 ====================
  void _showApiKeyDialog(String currentKey) {
    final controller = TextEditingController(text: currentKey);
    bool obscureText = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('DashScope API Key'),
            content: TextField(
              controller: controller,
              obscureText: obscureText,
              decoration: InputDecoration(
                hintText: '请输入阿里云 DashScope API Key',
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility : Icons.visibility_off,
                    size: 20,
                  ),
                  onPressed: () {
                    setDialogState(() {
                      obscureText = !obscureText;
                    });
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setDashScopeApiKey(controller.text.trim());
                  Navigator.pop(ctx);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== 称呼修改对话框 ====================
  void _showUserTitleDialog(String currentTitle) {
    final controller = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改称呼'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入称呼，如：医生、老师、主任等',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                ref.read(settingsProvider.notifier).setUserTitle(title);
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ==================== 测试连接 ====================
  Future<void> _testConnection() async {
    final apiKey = ref.read(settingsProvider).dashScopeApiKey;
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 API Key')),
      );
      return;
    }

    setState(() => _testingConnection = true);
    try {
      final success = await _aiService.testConnection(apiKey);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('连接成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接失败：${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  // ==================== 清除缓存 ====================
  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要删除所有临时录音和图片文件吗？\n已保存的病历附件不会受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final recordingsDir = Directory('${dir.path}/recordings');
        final imagesDir = Directory('${dir.path}/images');

        if (await recordingsDir.exists()) {
          await recordingsDir.delete(recursive: true);
        }
        if (await imagesDir.exists()) {
          await imagesDir.delete(recursive: true);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('缓存已清除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清除失败：$e')),
          );
        }
      }
    }
  }

  // ==================== 导出数据 ====================
  Future<void> _exportData() async {
    try {
      final db = DatabaseService();
      final patients = await db.getPatients();
      final List<Map<String, dynamic>> data = [];

      for (final p in patients) {
        final records = await db.getRecordsByPatient(p.id);
        data.add({
          'id': p.id,
          'name': p.name,
          'gender': p.gender,
          'age': p.age,
          'bedNo': p.bedNo,
          'department': p.department,
          'admissionDate': p.admissionDate.toIso8601String(),
          'status': p.status,
          'createdAt': p.createdAt.toIso8601String(),
          'records': records
              .map((r) => {
                    'id': r.id,
                    'patientId': r.patientId,
                    'type': r.type,
                    'content': r.content,
                    'audioPath': r.audioPath,
                    'imagePaths': r.imagePaths,
                    'createdAt': r.createdAt.toIso8601String(),
                    'updatedAt': r.updatedAt.toIso8601String(),
                  })
              .toList(),
        });
      }

      final dir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${dir.path}/exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${exportDir.path}/auscultpen_export_$timestamp.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出：${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    }
  }

  // ==================== 开源许可 ====================
  void _showLicenses() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _CustomLicensePage(
          applicationName: 'AuscultPen 听诊笔',
          applicationVersion: '0.5.1',
          applicationLegalese: 'Copyright © 2016-2026 Torway Studio. All rights reserved.',
        ),
      ),
    );
  }

  // ==================== 打开QQ频道 ====================
  Future<void> _openQQChannel() async {
    final uri = Uri.parse('https://pd.qq.com/s/8vs1iv1ks?b=9');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开链接')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          // 顶部 Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Center(
              child: Image.asset(
                'assets/images/app_about.png',
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),
          _buildSectionTitle('个性化'),
          _buildListTile(
            icon: Icons.badge_outlined,
            title: '称呼',
            subtitle: settings.userTitle,
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: () => _showUserTitleDialog(settings.userTitle),
          ),
          _buildSectionTitle('AI 服务配置'),
          _buildListTile(
            icon: Icons.key_outlined,
            title: 'DashScope API Key',
            subtitle: settings.hasApiKey ? '已配置' : '未配置',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  settings.hasApiKey ? Icons.check_circle : Icons.cancel,
                  color: settings.hasApiKey ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
            onTap: () => _showApiKeyDialog(settings.dashScopeApiKey),
          ),
          _buildListTile(
            icon: Icons.cloud_done_outlined,
            title: '测试连接',
            subtitle: '验证 API Key 是否有效',
            trailing: _testingConnection
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right, color: Color(0xFF1677FF)),
            onTap: _testingConnection ? null : _testConnection,
          ),
          _buildDropdownTile(
            icon: Icons.smart_toy_outlined,
            title: '默认病历模型',
            value: settings.defaultModel,
            items: SettingsState.availableModels,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setDefaultModel(v!),
          ),
          _buildSectionTitle('多媒体配置'),
          _buildSliderTile(
            icon: Icons.image_outlined,
            title: '图片压缩质量',
            value: settings.imageQuality.toDouble(),
            suffix: '${settings.imageQuality}%',
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setImageQuality(v.toInt()),
          ),
          _buildSwitchTile(
            icon: Icons.save_outlined,
            title: '自动保存草稿',
            subtitle: '编辑中途退出时保留内容',
            value: settings.autoSaveDraft,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setAutoSaveDraft(v),
          ),
          _buildSectionTitle('数据管理'),
          _buildListTile(
            icon: Icons.download_outlined,
            title: '导出所有数据',
            subtitle: '导出为 JSON 文件到文档目录',
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: _exportData,
          ),
          _buildListTile(
            icon: Icons.cleaning_services_outlined,
            title: '清除缓存',
            subtitle: '删除临时录音和图片文件',
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: _clearCache,
          ),
          _buildSectionTitle('关于'),
          _buildInfoTile(
            icon: Icons.info_outline,
            title: '版本号',
            trailing: '1.0.0',
          ),
          _buildListTile(
            icon: Icons.description_outlined,
            title: '开源许可',
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: _showLicenses,
          ),
          _buildListTile(
            icon: Icons.forum_outlined,
            title: 'QQ频道',
            subtitle: '加入官方频道交流反馈',
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: _openQQChannel,
          ),
          // 底部公司 Logo 和版权信息
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/tw_logo.png',
                  height: 48,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                Text(
                  'Copyright © 2016-2026 Torway Studio.\nAll rights reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 通用列表项组件 ====================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(icon, color: const Color(0xFF1677FF)),
          title: Text(title, style: const TextStyle(fontSize: 15)),
          subtitle: subtitle != null
              ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500]))
              : null,
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(icon, color: const Color(0xFF1677FF)),
          title: Text(title, style: const TextStyle(fontSize: 15)),
          trailing: DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1677FF),
            ),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required double value,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1677FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15)),
                    const Spacer(),
                    Text(
                      suffix,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1677FF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: const SliderThemeData(
                    activeTrackColor: Color(0xFF1677FF),
                    thumbColor: Color(0xFF1677FF),
                  ),
                  child: Slider(
                    value: value,
                    min: 50,
                    max: 100,
                    divisions: 10,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: SwitchListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          secondary: Icon(icon, color: const Color(0xFF1677FF)),
          title: Text(title, style: const TextStyle(fontSize: 15)),
          subtitle: subtitle != null
              ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500]))
              : null,
          value: value,
          activeTrackColor: const Color(0xFF1677FF),
          activeThumbColor: Colors.white,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(icon, color: const Color(0xFF1677FF)),
          title: Text(title, style: const TextStyle(fontSize: 15)),
          trailing: Text(
            trailing,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ),
      ),
    );
  }
}

/// 自定义开源许可页面（隐藏 Powered by Flutter）
class _CustomLicensePage extends StatefulWidget {
  final String applicationName;
  final String applicationVersion;
  final String applicationLegalese;

  const _CustomLicensePage({
    required this.applicationName,
    required this.applicationVersion,
    required this.applicationLegalese,
  });

  @override
  State<_CustomLicensePage> createState() => _CustomLicensePageState();
}

class _CustomLicensePageState extends State<_CustomLicensePage> {
  List<LicenseEntry> _licenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLicenses();
  }

  Future<void> _loadLicenses() async {
    final licenses = await LicenseRegistry.licenses.toList();
    setState(() {
      _licenses = licenses;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('开源许可'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 应用信息卡片
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          widget.applicationName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '版本 ${widget.applicationVersion}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.applicationLegalese,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 许可证列表
                ..._licenses.map((license) {
                  final packages = license.packages.toList();
                  final paragraphs = license.paragraphs.map((p) => p.text).join('\n\n');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        packages.isNotEmpty ? packages.join(', ') : '未知包',
                        style: const TextStyle(fontSize: 14),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            paragraphs,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
