import 'package:isar/isar.dart';

part 'todo_item.g.dart';

/// 待办事项数据模型
@collection
class TodoItem {
  /// 自增主键
  Id id = Isar.autoIncrement;

  /// 关联患者ID（可选，为空表示通用待办）
  @Index()
  int? patientId;

  /// 待办内容
  String content;

  /// 完成状态
  bool isCompleted;

  /// 创建时间
  DateTime createdAt;

  /// 完成时间
  DateTime? completedAt;

  TodoItem({
    this.id = Isar.autoIncrement,
    this.patientId,
    required this.content,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
  });
}
