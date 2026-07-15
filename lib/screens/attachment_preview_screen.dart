import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/settings_provider.dart';
import '../services/ai_service.dart';

/// 附件类型枚举
enum AttachmentType { audio, image }

/// 附件预览页
/// 支持查看录音附件的转文字结果、图片附件预览及 AI 解析
class AttachmentPreviewScreen extends ConsumerStatefulWidget {
  final AttachmentType type;
  final String path;

  const AttachmentPreviewScreen({
    super.key,
    required this.type,
    required this.path,
  });

  @override
  ConsumerState<AttachmentPreviewScreen> createState() =>
      _AttachmentPreviewScreenState();
}

class _AttachmentPreviewScreenState
    extends ConsumerState<AttachmentPreviewScreen> {
  final _aiService = AiService();

  // 音频播放器
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration? _duration;
  Duration _position = Duration.zero;

  // AI 解析结果
  String? _aiResult;
  bool _isAiProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == AttachmentType.audio) {
      _initAudioPlayer();
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _initAudioPlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setFilePath(widget.path);
      _duration = _audioPlayer!.duration;
      _audioPlayer!.positionStream.listen((pos) {
        if (mounted) {
          setState(() => _position = pos);
        }
      });
      _audioPlayer!.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });
      if (mounted) setState(() {});
    } catch (e) {
      // 音频初始化失败，不影响页面显示
    }
  }

  Future<void> _togglePlay() async {
    final player = _audioPlayer;
    if (player == null) return;

    if (_isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer?.seek(position);
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '00:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _getFileName() {
    return widget.path.split(Platform.pathSeparator).last;
  }

  String _formatFileSize() {
    try {
      final file = File(widget.path);
      if (!file.existsSync()) return '未知大小';
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return '未知大小';
    }
  }

  /// AI 解析附件
  Future<void> _analyzeWithAi() async {
    final settings = ref.read(settingsProvider);
    if (!settings.hasApiKey) {
      _showError('请先在设置中配置阿里云 API Key');
      return;
    }

    setState(() => _isAiProcessing = true);

    try {
      String result;
      if (widget.type == AttachmentType.audio) {
        result = await _aiService.speechToText(
          widget.path,
          apiKey: settings.dashScopeApiKey,
        );
      } else {
        result = await _aiService.recognizeImage(
          widget.path,
          apiKey: settings.dashScopeApiKey,
        );
      }

      if (mounted) {
        setState(() => _aiResult = result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 解析完成')),
        );
      }
    } catch (e) {
      _showError('AI 解析失败：${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isAiProcessing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAudio = widget.type == AttachmentType.audio;
    final title = isAudio ? '录音附件' : '图片附件';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFileInfoCard(),
            const SizedBox(height: 16),
            if (isAudio) _buildAudioPlayerCard(),
            if (!isAudio) _buildImagePreviewCard(),
            const SizedBox(height: 16),
            _buildAiAnalysisCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfoCard() {
    final isAudio = widget.type == AttachmentType.audio;
    return Container(
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1677FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAudio ? Icons.audiotrack : Icons.image,
              color: const Color(0xFF1677FF),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFileName(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isAudio ? '音频' : '图片'} · ${_formatFileSize()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          const Icon(
            Icons.graphic_eq,
            size: 64,
            color: Color(0xFF1677FF),
          ),
          const SizedBox(height: 16),
          const Text(
            '录音播放',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          // 进度条
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF1677FF),
              inactiveTrackColor: Colors.grey[200],
              thumbColor: const Color(0xFF1677FF),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _position.inSeconds.toDouble(),
              max: _duration?.inSeconds.toDouble() ?? 0.0,
              onChanged: (val) {
                _seekTo(Duration(seconds: val.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                Text(
                  _formatDuration(_duration),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 播放控制
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10),
                iconSize: 32,
                color: Colors.grey[700],
                onPressed: () {
                  final newPos = _position - const Duration(seconds: 10);
                  _seekTo(newPos < Duration.zero ? Duration.zero : newPos);
                },
              ),
              const SizedBox(width: 20),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFF1677FF),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: _togglePlay,
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.forward_10),
                iconSize: 32,
                color: Colors.grey[700],
                onPressed: () {
                  final newPos = _position + const Duration(seconds: 10);
                  if (_duration != null && newPos <= _duration!) {
                    _seekTo(newPos);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewCard() {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(widget.path),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildAiAnalysisCard() {
    final isAudio = widget.type == AttachmentType.audio;
    final actionText = isAudio ? '转文字' : 'AI 识别';

    return Container(
      width: double.infinity,
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
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 20, color: Color(0xFF1677FF)),
              const SizedBox(width: 8),
              const Text(
                'AI 解析',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_aiResult != null && !_isAiProcessing)
                TextButton.icon(
                  onPressed: _analyzeWithAi,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重新解析'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1677FF),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isAiProcessing)
            _buildAiLoadingWidget()
          else if (_aiResult != null)
            _buildAiResultWidget()
          else
            _buildAiEmptyWidget(actionText, isAudio),
        ],
      ),
    );
  }

  Widget _buildAiLoadingWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
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
            const SizedBox(height: 16),
            const Text(
              'AI 正在解析中...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '请稍候，大约需要 10-30 秒',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiResultWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SelectableText(
        _aiResult!,
        style: const TextStyle(
          fontSize: 14,
          height: 1.7,
        ),
      ),
    );
  }

  Widget _buildAiEmptyWidget(String actionText, bool isAudio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAudio
              ? '点击下方按钮，将录音转换为文字内容'
              : '点击下方按钮，AI 识别图片中的文字内容',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isAiProcessing ? null : _analyzeWithAi,
            icon: const Icon(Icons.auto_awesome),
            label: Text('开始$actionText'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1677FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
