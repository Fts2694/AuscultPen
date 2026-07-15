import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medical_record.dart';

/// 病历卡片组件
/// 显示创建时间和内容摘要（前50字）
class RecordCard extends StatelessWidget {
  final MedicalRecord record;
  final VoidCallback? onTap;

  const RecordCard({
    super.key,
    required this.record,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt);
    final summary = record.content.length > 50
        ? '${record.content.substring(0, 50)}...'
        : record.content;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1677FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      record.type,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1677FF),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
