import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../models/todo_item.dart';
import 'database_provider.dart';

/// 待办筛选状态（全部/未完成/已完成）
final todoFilterProvider = StateProvider<String>((ref) => '全部');

/// 待办列表 Provider
final todosProvider = AsyncNotifierProvider<TodosNotifier, List<TodoItem>>(
  TodosNotifier.new,
);

class TodosNotifier extends AsyncNotifier<List<TodoItem>> {
  @override
  Future<List<TodoItem>> build() async {
    final db = ref.read(databaseProvider);
    final filter = ref.watch(todoFilterProvider);
    switch (filter) {
      case '未完成':
        return db.getTodos(completed: false);
      case '已完成':
        return db.getTodos(completed: true);
      default:
        return db.getTodos();
    }
  }

  Future<Id> addTodo(TodoItem todo) async {
    final db = ref.read(databaseProvider);
    final id = await db.addTodo(todo);
    ref.invalidateSelf();
    return id;
  }

  Future<Id> updateTodo(TodoItem todo) async {
    final db = ref.read(databaseProvider);
    final id = await db.updateTodo(todo);
    ref.invalidateSelf();
    return id;
  }

  Future<void> deleteTodo(int id) async {
    final db = ref.read(databaseProvider);
    await db.deleteTodo(id);
    ref.invalidateSelf();
  }

  Future<void> toggleComplete(TodoItem todo) async {
    final db = ref.read(databaseProvider);
    final updated = TodoItem(
      id: todo.id,
      patientId: todo.patientId,
      content: todo.content,
      isCompleted: !todo.isCompleted,
      createdAt: todo.createdAt,
      completedAt: !todo.isCompleted ? DateTime.now() : null,
    );
    await db.updateTodo(updated);
    ref.invalidateSelf();
  }
}

/// 某患者的待办列表 Provider
final patientTodosProvider =
    FutureProvider.family<List<TodoItem>, int>((ref, patientId) async {
  final db = ref.read(databaseProvider);
  return db.getTodosByPatient(patientId);
});

/// 未完成待办数量 Provider
/// 依赖 todosProvider，当待办列表变化时自动刷新
final pendingTodoCountProvider = FutureProvider<int>((ref) async {
  // watch todosProvider 使得待办变化时自动刷新
  ref.watch(todosProvider);
  final db = ref.read(databaseProvider);
  return db.getPendingTodoCount();
});
