import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medical_record.dart';
import 'attachment_preview_screen.dart';

/// 病历预览页
/// 展示病历完整内容和所有附件
class RecordPreviewScreen extends StatefulWidget {
  final MedicalRecord record;
  final String patientName;

  const RecordPreviewScreen({
    super.key,
    required this.record,
    required this.patientName,
  });

  @override
  State<RecordPreviewScreen> createState() => _RecordPreviewScreenState();
}

class _RecordPreviewScreenState extends State<RecordPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final hasAttachments =
        record.audioPath != null || record.imagePaths.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(record.type),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(record),
            const SizedBox(height: 16),
            _buildContentCard(record.content),
            const SizedBox(height: 16),
            if (hasAttachments) _buildAttachmentsSection(record),
            const SizedBox(height: 24),
            Text(
              '创建时间：${DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            if (record.updatedAt.difference(record.createdAt).inMinutes > 1)
              Text(
                '更新时间：${DateFormat('yyyy-MM-dd HH:mm').format(record.updatedAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(MedicalRecord record) {
    return Container(
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
            color: const Color(0xFF1677FF).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.description, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patientName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.type,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${record.content.length} 字',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(String content) {
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
              const Icon(Icons.article_outlined,
                  size: 18, color: Color(0xFF1677FF)),
              const SizedBox(width: 8),
              const Text(
                '病历内容',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content.isEmpty ? '暂无内容' : content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(MedicalRecord record) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '附件 (${_attachmentCount(record)})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        if (record.audioPath != null) _buildAudioItem(record.audioPath!),
        if (record.imagePaths.isNotEmpty)
          ...record.imagePaths.map((p) => _buildImageItem(p)),
      ],
    );
  }

  int _attachmentCount(MedicalRecord record) {
    int count = 0;
    if (record.audioPath != null) count++;
    count += record.imagePaths.length;
    return count;
  }

  Widget _buildAudioItem(String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openAttachmentPreview(
            type: AttachmentType.audio,
            path: path,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1677FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.audiotrack,
                    color: Color(0xFF1677FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '录音附件',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatFileSize(path),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageItem(String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openAttachmentPreview(
            type: AttachmentType.image,
            path: path,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(path),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFileName(path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '图片 · ${_formatFileSize(path)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  String _formatFileSize(String path) {
    try {
      final file = File(path);
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

  void _openAttachmentPreview({
    required AttachmentType type,
    required String path,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttachmentPreviewScreen(
          type: type,
          path: path,
        ),
      ),
    );
  }
}
