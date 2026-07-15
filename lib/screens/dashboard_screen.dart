import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/patient.dart';
import '../providers/patients_provider.dart';
import '../providers/todos_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../services/media_service.dart';
import 'todo_screen.dart';
import 'patient_list_screen.dart';
import 'record_edit_screen.dart';
import 'patient_detail_screen.dart';
import '../widgets/add_patient_sheet.dart';

/// 首页仪表盘
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _mediaService = MediaService();
  final _aiService = AiService();
  bool _isParsing = false;
  bool _isRecording = false;

  /// 拍照识别流程 - 直接进入添加记录页面，附件中带图片
  Future<void> _captureAndParseRecord() async {
    // 显示图片来源选择菜单
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照'),
              subtitle: const Text('调用相机拍摄'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册/文件选择'),
              subtitle: const Text('选择已有图片'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      String? imagePath;

      if (source == 'camera') {
        imagePath = await _mediaService.takePhoto();
        // Windows平台相机调用失败时，自动提示切换到文件选择
        if (imagePath == null && (Platform.isWindows || Platform.isLinux)) {
          if (mounted) {
            final useGallery = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('相机不可用'),
                content: const Text('未检测到可用的相机设备，是否改为从文件选择图片？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('选择文件'),
                  ),
                ],
              ),
            );
            if (useGallery == true) {
              final paths = await _mediaService.pickImagesFromGallery();
              if (paths.isNotEmpty) {
                imagePath = paths.first;
              }
            }
          }
        }
      } else {
        final paths = await _mediaService.pickImagesFromGallery();
        if (paths.isNotEmpty) {
          imagePath = paths.first;
        }
      }

      if (imagePath == null) return;

      if (mounted) {
        // 直接跳转到添加记录页面，图片作为附件
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecordEditScreen(
              patientId: 0,
              initialType: '日常病程',
              initialImagePaths: [imagePath!],
              isFromCamera: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('操作失败：${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 录音识别流程
  Future<void> _recordAndRecognize() async {
    final settings = ref.read(settingsProvider);
    if (!settings.hasApiKey) {
      _showError('请先在设置中配置阿里云 API Key');
      return;
    }

    // 请求麦克风权限
    final hasPermission = await _mediaService.requestMicrophonePermission();
    if (!hasPermission) {
      _showError('麦克风权限未授权，请在设置中开启');
      return;
    }

    if (_isRecording) {
      // 停止录音并识别
      try {
        final path = await _mediaService.stopRecording();
        setState(() {
          _isRecording = false;
          _isParsing = true;
        });

        if (path == null) {
          setState(() => _isParsing = false);
          _showError('录音失败，未获取到音频文件');
          return;
        }

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF1677FF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'AI 正在识别语音...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '请稍候，大约需要 5-30 秒',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final text = await _aiService.speechToText(
          path,
          apiKey: settings.dashScopeApiKey,
        );

        if (mounted) {
          Navigator.of(context).pop(); // 关闭对话框
          setState(() => _isParsing = false);

          if (text.trim().isEmpty) {
            _showError('语音识别结果为空');
            return;
          }

          // 跳转到编辑页，预填语音转文字内容
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecordEditScreen(
                patientId: 0,
                initialType: '日常病程',
                initialContent: text,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          try {
            Navigator.of(context).pop();
          } catch (_) {}
          setState(() {
            _isRecording = false;
            _isParsing = false;
          });
          _showError('识别失败：${e.toString().replaceAll('Exception: ', '')}');
        }
      }
    } else {
      // 开始录音
      try {
        await _mediaService.startRecording();
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        _showError('录音启动失败：${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  int _countInHospital(List<Patient> patients) {
    return patients.where((p) => p.status == '在院').length;
  }

  int _countPreDischarge(List<Patient> patients) {
    return patients.where((p) => p.status == '预出院').length;
  }

  int _countTodayAdmissions(List<Patient> patients) {
    final today = DateTime.now();
    return patients.where((p) {
      return p.admissionDate.year == today.year &&
          p.admissionDate.month == today.month &&
          p.admissionDate.day == today.day;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider);
    final pendingCountAsync = ref.watch(pendingTodoCountProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(),
            const SizedBox(height: 16),
            // 统计卡片
            patientsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('加载失败：$error')),
              data: (patients) => _buildStatsRow(
                inHospitalCount: _countInHospital(patients),
                pendingCount: pendingCountAsync.value ?? 0,
                preDischargeCount: _countPreDischarge(patients),
                todayCount: _countTodayAdmissions(patients),
              ),
            ),
            const SizedBox(height: 20),
            // 快捷操作
            _buildQuickActions(),
            // 预出院患者（无数据时不显示，也不留间距）
            _buildPreDischargeSection(patientsAsync),
            // 最近动态
            _buildRecentSection(patientsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final userTitle = ref.watch(settingsProvider).userTitle;
    String greeting;
    if (hour < 12) {
      greeting = '早上好';
    } else if (hour < 18) {
      greeting = '下午好';
    } else {
      greeting = '晚上好';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting，$userTitle',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(DateTime.now()),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required int inHospitalCount,
    required int pendingCount,
    required int preDischargeCount,
    required int todayCount,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.local_hospital_outlined,
                title: '在院患者',
                count: inHospitalCount,
                color: const Color(0xFF1677FF),
                bgColor: const Color(0xFF1677FF).withValues(alpha: 0.08),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PatientListScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                icon: Icons.logout,
                title: '预出院',
                count: preDischargeCount,
                color: const Color(0xFFFF8C00),
                bgColor: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PatientListScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                icon: Icons.checklist_outlined,
                title: '待办事项',
                count: pendingCount,
                color: const Color(0xFF52C41A),
                bgColor: const Color(0xFF52C41A).withValues(alpha: 0.1),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TodoScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '快捷操作',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        // 拍病历识别 + 录音识别 并列按钮
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _isParsing ? null : _captureAndParseRecord,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1677FF), Color(0xFF4096FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1677FF).withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '拍照识别',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '病历/检验报告',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _isParsing ? null : _recordAndRecognize,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _isRecording
                            ? const Color(0xFFFF4D4F)
                            : const Color(0xFF722ED1),
                        _isRecording
                            ? const Color(0xFFFF7875)
                            : const Color(0xFF9254DE),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording
                                ? const Color(0xFFFF4D4F)
                                : const Color(0xFF722ED1))
                            .withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isRecording ? '点击停止' : '录音识别',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isRecording ? '录音中...' : '语音快速录入',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 快速新建患者按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  AddPatientSheet.show(context);
                },
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('快速新建患者'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1677FF),
                  side: const BorderSide(color: Color(0xFF1677FF)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreDischargeSection(AsyncValue<List<Patient>> patientsAsync) {
    return patientsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (patients) {
        final preDischargePatients =
            patients.where((p) => p.status == '预出院').toList();
        if (preDischargePatients.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      '预出院患者',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8C00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${preDischargePatients.length}人',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF8C00),
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PatientListScreen()),
                    );
                  },
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: preDischargePatients.length > 3
                    ? 3
                    : preDischargePatients.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (ctx, index) {
                  final patient = preDischargePatients[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          const Color(0xFFFF8C00).withValues(alpha: 0.1),
                      child: Text(
                        patient.name[0],
                        style: const TextStyle(
                          color: Color(0xFFFF8C00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8C00)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '预出院',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF8C00),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${patient.department} · ${patient.bedNo ?? ''}床',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                    onTap: () {
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              PatientDetailScreen(patientId: patient.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        );
      },
    );
  }

  Widget _buildRecentSection(AsyncValue<List<Patient>> patientsAsync) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '最近动态',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PatientListScreen()),
                );
              },
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        patientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('加载失败：$error')),
          data: (patients) {
            if (patients.isEmpty) {
              return _buildEmptyRecent();
            }
            return _buildRecentList(patients);
          },
        ),
      ],
      ),
    );
  }

  Widget _buildEmptyRecent() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              '暂无动态',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList(List<Patient> patients) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: patients.length > 5 ? 5 : patients.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (ctx, index) {
          final patient = patients[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1677FF).withValues(alpha: 0.1),
              child: Text(
                patient.name[0],
                style: const TextStyle(
                  color: Color(0xFF1677FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            title: Text(
              patient.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${patient.department} · ${patient.status}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: () {
              Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) =>
                      PatientDetailScreen(patientId: patient.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
