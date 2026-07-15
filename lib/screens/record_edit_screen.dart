import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medical_record.dart';
import '../providers/patients_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/media_service.dart';
import '../widgets/add_patient_sheet.dart';

/// 病历编辑页
/// 支持新增/编辑病历，集成语音录入、拍照识别、AI 生成
class RecordEditScreen extends ConsumerStatefulWidget {
  final int patientId;
  final int? recordId;
  final String initialType;
  final String? initialContent;
  final List<String>? initialImagePaths;
  final bool isFromCamera;
  final String? matchedPatientName;

  const RecordEditScreen({
    super.key,
    required this.patientId,
    this.recordId,
    this.initialType = '日常病程',
    this.initialContent,
    this.initialImagePaths,
    this.isFromCamera = false,
    this.matchedPatientName,
  });

  @override
  ConsumerState<RecordEditScreen> createState() => _RecordEditScreenState();
}

class _RecordEditScreenState extends ConsumerState<RecordEditScreen> {
  final _contentController = TextEditingController();
  final _mediaService = MediaService();
  final _aiService = AiService();

  late String _recordType;
  bool _isSaving = false;
  bool _isAiProcessing = false;
  bool _isLoading = true;
  int? _selectedPatientId;

  // 录音状态
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String? _audioPath;
  bool _isTranscribingAudio = false;

  // 图片列表
  List<String> _imagePaths = [];
  String? _processingImagePath;

  bool get _isEdit => widget.recordId != null;
  bool get _needsPatientSelection => widget.patientId == 0;

  @override
  void initState() {
    super.initState();
    _recordType = widget.initialType;
    // 如果有智能匹配的患者，直接选中
    if (widget.matchedPatientName != null) {
      _selectedPatientId = widget.patientId;
    }
    _loadData();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _mediaService.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 加载编辑数据（编辑模式）
  Future<void> _loadData() async {
    if (widget.recordId != null) {
      final db = DatabaseService();
      final records = await db.getRecordsByPatient(widget.patientId);
      final record = records.firstWhere(
        (r) => r.id == widget.recordId,
        orElse: () => MedicalRecord(
          patientId: widget.patientId,
          type: _recordType,
          content: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (mounted) {
        setState(() {
          _recordType = record.type;
          _contentController.text = record.content;
          _audioPath = record.audioPath;
          _imagePaths = List.from(record.imagePaths);
          _isLoading = false;
        });
      }
    } else {
      // 新增模式：可能有初始内容和图片（拍病历识别）
      if (mounted) {
        setState(() {
          if (widget.initialContent != null) {
            _contentController.text = widget.initialContent!;
          }
          if (widget.initialImagePaths != null) {
            _imagePaths = List.from(widget.initialImagePaths!);
          }
          _isLoading = false;
        });
      }
    }
  }

  // ==================== 录音相关 ====================

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final path = await _mediaService.startRecording();
      _audioPath = path;
      _recordDuration = Duration.zero;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _recordDuration += const Duration(seconds: 1);
        });
      });
      setState(() {
        _isRecording = true;
        _isPaused = false;
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    await _mediaService.stopRecording();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
  }

  Future<void> _togglePause() async {
    if (_isPaused) {
      await _mediaService.resumeRecording();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _recordDuration += const Duration(seconds: 1);
        });
      });
      setState(() => _isPaused = false);
    } else {
      await _mediaService.pauseRecording();
      _recordTimer?.cancel();
      setState(() => _isPaused = true);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // ==================== 图片相关 ====================

  Future<void> _takePhoto() async {
    try {
      final path = await _mediaService.takePhoto();
      if (path != null) {
        setState(() {
          _imagePaths.add(path);
        });
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final paths = await _mediaService.pickImagesFromGallery();
      if (paths.isNotEmpty) {
        setState(() {
          _imagePaths.addAll(paths);
        });
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _removeImage(String path) {
    setState(() {
      _imagePaths.remove(path);
    });
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 附件 AI 识别 ====================

  /// 将文字插入到当前光标位置
  void _insertTextAtCursor(String text) {
    final controller = _contentController;
    final selection = controller.selection;
    final textBefore = selection.isValid
        ? controller.text.substring(0, selection.start)
        : controller.text;
    final textAfter = selection.isValid
        ? controller.text.substring(selection.end)
        : '';
    final newText = '$textBefore$text$textAfter';
    controller.text = newText;
    final newPosition = textBefore.length + text.length;
    controller.selection = TextSelection.collapsed(offset: newPosition);
    setState(() {});
  }

  /// 录音转文字
  Future<void> _transcribeAudio() async {
    final audioPath = _audioPath;
    if (audioPath == null) return;

    final settings = ref.read(settingsProvider);
    if (!settings.hasApiKey) {
      _showError('请先在设置中配置阿里云 API Key');
      return;
    }

    setState(() => _isTranscribingAudio = true);

    try {
      final result = await _aiService.speechToText(
        audioPath,
        apiKey: settings.dashScopeApiKey,
      );
      if (mounted && result.isNotEmpty) {
        _insertTextAtCursor(result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音转文字完成，已插入到光标处')),
        );
      }
    } catch (e) {
      _showError('语音转文字失败：${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isTranscribingAudio = false);
    }
  }

  /// 图片 AI 识别并插入文本
  Future<void> _recognizeImage(String imagePath) async {
    final settings = ref.read(settingsProvider);
    if (!settings.hasApiKey) {
      _showError('请先在设置中配置阿里云 API Key');
      return;
    }

    setState(() => _processingImagePath = imagePath);

    try {
      final result = await _aiService.recognizeImage(
        imagePath,
        apiKey: settings.dashScopeApiKey,
      );
      if (mounted && result.isNotEmpty) {
        _insertTextAtCursor('\n$result\n');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片识别完成，已插入到光标处')),
        );
      }
    } catch (e) {
      _showError('图片识别失败：${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _processingImagePath = null);
    }
  }

  // ==================== AI 相关 ====================

  Future<void> _generateByAi() async {
    final settings = ref.read(settingsProvider);
    if (!settings.hasApiKey) {
      _showError('请先在设置中配置阿里云 API Key');
      return;
    }

    final rawText = _contentController.text.trim();
    if (rawText.isEmpty) {
      _showError('请先输入或录制一些内容，再使用 AI 生成');
      return;
    }

    setState(() => _isAiProcessing = true);

    try {
      final result = await _aiService.generateMedicalRecord(
        rawText,
        _recordType,
        apiKey: settings.dashScopeApiKey,
      );
      if (mounted) {
        _contentController.text = result;
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isAiProcessing = false);
    }
  }

  Future<void> _polishByAi() async {
    final settings = ref.read(settingsProvider);
    if (!settings.hasApiKey) {
      _showError('请先在设置中配置阿里云 API Key');
      return;
    }

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showError('内容为空，无需润色');
      return;
    }

    setState(() => _isAiProcessing = true);

    try {
      final result = await _aiService.polishContent(
        content,
        apiKey: settings.dashScopeApiKey,
      );
      if (mounted) {
        _contentController.text = result;
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isAiProcessing = false);
    }
  }

  /// AI 解析报告（解析附件中的检验检查图片，将结果插入文本）
  Future<void> _parseReportByAi() async {
    final settings = ref.read(settingsProvider);
    if (!settings.hasApiKey) {
      _showError('请先在设置中配置阿里云 API Key');
      return;
    }

    if (_imagePaths.isEmpty) {
      _showError('请先添加检验检查报告的图片');
      return;
    }

    setState(() => _isAiProcessing = true);

    try {
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('【检验检查结果解析】');

      for (var i = 0; i < _imagePaths.length; i++) {
        final path = _imagePaths[i];
        final result = await _aiService.parseLabResultImage(
          path,
          apiKey: settings.dashScopeApiKey,
        );
        if (result.isNotEmpty) {
          if (_imagePaths.length > 1) {
            buffer.writeln('--- 图${i + 1} ---');
          }
          buffer.writeln(result);
        }
      }

      final fullText = buffer.toString().trim();
      if (mounted && fullText.isNotEmpty) {
        _insertTextAtCursor('\n$fullText\n');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('报告解析完成，已插入到光标处')),
        );
      }
    } catch (e) {
      _showError('解析失败：${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isAiProcessing = false);
    }
  }

  void _showAiMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('AI 生成病历'),
              subtitle: const Text('根据口语化描述生成结构化病历'),
              onTap: () {
                Navigator.pop(ctx);
                _generateByAi();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('AI 润色内容'),
              subtitle: const Text('规范医学术语，优化表达'),
              onTap: () {
                Navigator.pop(ctx);
                _polishByAi();
              },
            ),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('AI 解析报告'),
              subtitle: const Text('解析附件中的检验检查图片'),
              onTap: () {
                Navigator.pop(ctx);
                _parseReportByAi();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 保存 ====================

  Future<void> _saveRecord() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showError('病历内容不能为空');
      return;
    }

    final patientId = _needsPatientSelection
        ? _selectedPatientId
        : widget.patientId;
    if (patientId == null || patientId == 0) {
      _showError('请先选择关联的患者');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      if (_isEdit) {
        // 编辑模式：需要重新读取原记录再更新
        final db = DatabaseService();
        final records = await db.getRecordsByPatient(widget.patientId);
        final existing = records.firstWhere(
          (r) => r.id == widget.recordId,
          orElse: () => MedicalRecord(
            patientId: patientId,
            type: _recordType,
            content: '',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final updated = MedicalRecord(
          id: existing.id,
          patientId: patientId,
          type: _recordType,
          content: content,
          audioPath: _audioPath,
          imagePaths: _imagePaths,
          createdAt: existing.createdAt,
          updatedAt: now,
        );
        await db.addMedicalRecord(updated);
      } else {
        final record = MedicalRecord(
          patientId: patientId,
          type: _recordType,
          content: content,
          audioPath: _audioPath,
          imagePaths: _imagePaths,
          createdAt: now,
          updatedAt: now,
        );
        final db = DatabaseService();
        await db.addMedicalRecord(record);
      }

      // 刷新患者列表和病历列表
      ref.invalidate(medicalRecordsProvider(patientId));
      ref.invalidate(patientsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('保存失败：$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 显示患者选择器
  void _showPatientPicker() async {
    final patientsAsync = ref.read(patientsProvider);
    patientsAsync.whenData((patients) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择关联患者',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: patients.length,
                  itemBuilder: (ctx, index) {
                    final patient = patients[index];
                    final isSelected = _selectedPatientId == patient.id;
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(patient.name),
                      subtitle:
                          Text('${patient.department} · ${patient.status}'),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFF1677FF))
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedPatientId = patient.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// 新建患者并自动选中
  void _showAddNewPatient() async {
    await AddPatientSheet.show(context);
    // 新建后，刷新患者列表，并自动选中最新的患者
    final patientsAsync = ref.read(patientsProvider);
    patientsAsync.whenData((patients) {
      if (patients.isNotEmpty && mounted) {
        setState(() => _selectedPatientId = patients.first.id);
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(_isEdit ? '编辑记录' : '添加记录'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.mic),
                tooltip: '语音录入',
                color: _isRecording ? Colors.red : null,
                onPressed: _toggleRecording,
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt),
                tooltip: '拍照识别',
                onPressed: _showImagePickerSheet,
              ),
              PopupMenuButton<String>(
                initialValue: _recordType,
                tooltip: '病历类型',
                onSelected: (value) {
                  setState(() => _recordType = value);
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: '入院记录', child: Text('入院记录')),
                  PopupMenuItem(value: '首次病程', child: Text('首次病程')),
                  PopupMenuItem(value: '日常病程', child: Text('日常病程')),
                  PopupMenuItem(value: '手术记录', child: Text('手术记录')),
                ],
                icon: const Icon(Icons.category_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              // 患者选择栏（拍照识别模式或未关联患者）
              if (_needsPatientSelection || widget.matchedPatientName != null)
                _buildPatientSelectionBar(),
              // 录音状态条
              if (_isRecording) _buildRecordingBar(),
              // 图片预览区
              if (_imagePaths.isNotEmpty) _buildImageStrip(),
              // 录音附件提示
              if (_audioPath != null && !_isRecording)
                _buildAudioAttachment(),
              // 类型标签
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1677FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _recordType,
                        style: const TextStyle(
                          color: Color(0xFF1677FF),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_contentController.text.length} 字',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              // AI免责提示
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Colors.orange[400]),
                    const SizedBox(width: 4),
                    Text(
                      'AI生成仅供参考，请结合临床仔细判断',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[400],
                      ),
                    ),
                  ],
                ),
              ),
              // 内容编辑区
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: '在此输入病历内容，或点击上方语音/拍照快捷录入...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.6),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),
              // 底部操作栏
              _buildBottomBar(),
            ],
          ),
        ),
        // AI 处理遮罩
        if (_isAiProcessing) _buildAiLoadingMask(),
      ],
    );
  }

  // ==================== 子组件 ====================

  Widget _buildPatientSelectionBar() {
    final patientsAsync = ref.watch(patientsProvider);
    final isMatched = widget.matchedPatientName != null;
    final bgColor = isMatched
        ? const Color(0xFFF0F9EB)
        : const Color(0xFFFFF8E6);
    final iconColor =
        isMatched ? const Color(0xFF52C41A) : const Color(0xFFFF8C00);
    final textColor =
        isMatched ? const Color(0xFF52C41A) : const Color(0xFFFF8C00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: bgColor,
      child: Row(
        children: [
          Icon(
            isMatched ? Icons.check_circle : Icons.person_add_alt_1,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMatched
                  ? '智能匹配患者${widget.matchedPatientName}'
                  : '尚未关联患者，请选择或新建后保存',
              style: TextStyle(
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
          GestureDetector(
            onTap: _showPatientPicker,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedPatientId != null
                    ? const Color(0xFF1677FF)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedPatientId != null
                      ? const Color(0xFF1677FF)
                      : Colors.grey[300]!,
                ),
              ),
              child: patientsAsync.when(
                data: (patients) {
                  final patient = patients
                      .where((p) => p.id == _selectedPatientId)
                      .toList();
                  final name = patient.isNotEmpty ? patient.first.name : '选择患者';
                  return Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedPatientId != null
                          ? Colors.white
                          : const Color(0xFF1677FF),
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
                loading: () => Text(
                  '加载中...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                error: (_, _) => Text(
                  '选择患者',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showAddNewPatient,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF52C41A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '新建患者',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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

  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.withValues(alpha: 0.05),
      child: Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '正在录音  ${_formatDuration(_recordDuration)}',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: _togglePause,
            color: Colors.grey[700],
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: _stopRecording,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildImageStrip() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _imagePaths.length,
        itemBuilder: (ctx, index) {
          final path = _imagePaths[index];
          final isProcessing = _processingImagePath == path;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(path),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                if (isProcessing)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: isProcessing ? null : () => _recognizeImage(path),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1677FF).withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'AI识别',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => _removeImage(path),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioAttachment() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.audiotrack,
              size: 20, color: Color(0xFF1677FF)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '录音附件',
              style: TextStyle(fontSize: 14),
            ),
          ),
          TextButton.icon(
            onPressed: _isTranscribingAudio ? null : _transcribeAudio,
            icon: _isTranscribingAudio
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.text_fields, size: 18),
            label: Text(_isTranscribingAudio ? '转写中' : '转文字'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1677FF),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () {
              setState(() => _audioPath = null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: _showAiMenu,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI 处理'),
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
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRecord,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? '保存中' : '保存'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiLoadingMask() {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF1677FF),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'AI 正在处理中...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '请稍候，生成时间约 10-30 秒',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
