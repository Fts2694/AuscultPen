import 'package:isar/isar.dart';

part 'patient.g.dart';

/// 患者数据模型
@collection
class Patient {
  /// 自增主键
  Id id = Isar.autoIncrement;

  /// 姓名
  String name;

  /// 性别（男/女）
  String gender;

  /// 年龄
  int age;

  /// 床号（可选）
  String? bedNo;

  /// 科室（内科/外科/其他）
  String department;

  /// 入院时间
  DateTime admissionDate;

  /// 状态（在院/出院）
  String status;

  /// 创建时间
  DateTime createdAt;

  Patient({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.gender,
    required this.age,
    this.bedNo,
    required this.department,
    required this.admissionDate,
    required this.status,
    required this.createdAt,
  });
}
