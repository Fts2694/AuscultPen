import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/patient.dart';

/// 患者卡片组件
/// 白色背景 + 16px 圆角 + 轻微阴影
/// 左侧：姓名（大字加粗）+ 床号/科室（小字灰色）
/// 右侧：入院日期 + 状态标签
class PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback? onTap;

  const PatientCard({
    super.key,
    required this.patient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isInHospital = patient.status == '在院';
    final isPreDischarge = patient.status == '预出院';
    final dateStr = DateFormat('yyyy-MM-dd').format(patient.admissionDate);

    Color statusColor;
    Color statusBgColor;
    if (isInHospital) {
      statusColor = const Color(0xFF1677FF);
      statusBgColor = const Color(0xFF1677FF).withValues(alpha: 0.1);
    } else if (isPreDischarge) {
      statusColor = const Color(0xFFFF8C00);
      statusBgColor = const Color(0xFFFF8C00).withValues(alpha: 0.1);
    } else {
      // 出院 - 使用明确的灰色
      statusColor = const Color(0xFF8C8C8C);
      statusBgColor = const Color(0xFF8C8C8C).withValues(alpha: 0.12);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isPreDischarge) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF8C00).withValues(alpha: 0.15),
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
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${patient.gender} · ${patient.age}岁 · ${patient.department}'
                      '${patient.bedNo != null && patient.bedNo!.isNotEmpty ? ' · ${patient.bedNo}床' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      patient.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '入院 $dateStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
