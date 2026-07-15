import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// 多媒体服务
/// 封装录音、拍照、权限处理等功能
class MediaService {
  final AudioRecorder _recorder = AudioRecorder();
  final ImagePicker _imagePicker = ImagePicker();

  // ==================== 录音相关 ====================

  /// 检查麦克风权限
  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// 请求麦克风权限
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// 检查是否正在录音
  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  /// 开始录音
  /// 返回录音文件路径
  Future<String> startRecording() async {
    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission) {
      throw Exception('麦克风权限未授权，请在设置中开启');
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}/recordings/record_$timestamp.wav';

    // 确保目录存在
    final recordingsDir = Directory('${dir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000,
      ),
      path: path,
    );

    return path;
  }

  /// 暂停录音
  Future<void> pauseRecording() async {
    await _recorder.pause();
  }

  /// 恢复录音
  Future<void> resumeRecording() async {
    await _recorder.resume();
  }

  /// 停止录音
  /// 返回录音文件路径
  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path;
  }

  /// 取消录音并删除文件
  Future<void> cancelRecording() async {
    final path = await _recorder.stop();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  // ==================== 图片相关 ====================

  /// 检查相机权限
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// 请求相机权限
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// 检查相册权限
  Future<bool> hasPhotoPermission() async {
    final status = await Permission.photos.status;
    return status.isGranted;
  }

  /// 请求相册权限
  Future<bool> requestPhotoPermission() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  /// 使用相机拍照
  /// 返回图片文件路径
  Future<String?> takePhoto() async {
    // 移动平台检查权限
    if (!kIsWeb && !Platform.isWindows && !Platform.isLinux) {
      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        throw Exception('相机权限未授权，请在设置中开启');
      }
    }

    try {
      final imageFuture = _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      // Windows/Linux 桌面平台添加 10 秒超时，避免相机调用卡死
      final image = kIsWeb || (!Platform.isWindows && !Platform.isLinux)
          ? await imageFuture
          : await imageFuture.timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('相机调用超时，请检查相机是否可用或选择从文件上传');
              },
            );

      if (image == null) return null;

      // 将图片移动到应用文档目录
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${dir.path}/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${imagesDir.path}/photo_$timestamp.jpg';
      await image.saveTo(newPath);

      return newPath;
    } catch (e) {
      // Windows 平台相机调用失败时，提示用户使用文件选择
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
        throw Exception('相机调用失败：${e.toString().replaceAll('Exception: ', '')}\n建议使用「从文件选择」功能上传图片');
      }
      rethrow;
    }
  }

  /// 从相册选择图片
  /// 返回图片文件路径列表
  Future<List<String>> pickImagesFromGallery() async {
    // 移动平台检查权限
    if (!kIsWeb && !Platform.isWindows && !Platform.isLinux) {
      final hasPermission = await requestPhotoPermission();
      if (!hasPermission) {
        throw Exception('相册权限未授权，请在设置中开启');
      }
    }

    final images = await _imagePicker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (images.isEmpty) return [];

    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final List<String> paths = [];
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${imagesDir.path}/gallery_${timestamp}_$i.jpg';
      await image.saveTo(newPath);
      paths.add(newPath);
    }

    return paths;
  }

  // ==================== 清理 ====================

  /// 释放资源
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
