import 'package:isar/isar.dart';

part 'medical_record.g.dart';

/// 病历记录数据模型
@collection
class MedicalRecord {
  /// 自增主键
  Id id = Isar.autoIncrement;

  /// 关联患者ID
  @Index()
  int patientId;

  /// 类型（入院记录/首次病程/日常病程/手术记录）
  String type;

  /// Markdown格式的病历内容
  String content;

  /// 原始录音文件路径（可选）
  String? audioPath;

  /// 原始图片路径列表（默认空列表）
  List<String> imagePaths = [];

  /// 创建时间
  DateTime createdAt;

  /// 更新时间
  DateTime updatedAt;

  MedicalRecord({
    this.id = Isar.autoIncrement,
    required this.patientId,
    required this.type,
    required this.content,
    this.audioPath,
    this.imagePaths = const [],
    required this.createdAt,
    required this.updatedAt,
  });
}
