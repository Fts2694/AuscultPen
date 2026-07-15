import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// AI 服务
/// 封装阿里云 DashScope API 调用，包括：
/// - 文本生成病历（Qwen-Turbo）
/// - 图片识别（Qwen-VL）
/// - 内容润色
class AiService {
  static const String _baseUrl =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation';
  static const String _vlBaseUrl =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';
  static const String _asrUrl =
      'https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription';
  static const String _taskUrl =
      'https://dashscope.aliyuncs.com/api/v1/tasks';
  static const String _uploadPolicyUrl =
      'https://dashscope.aliyuncs.com/api/v1/uploads';

  final Dio _dio = Dio();

  /// 根据口语化文本生成结构化病历
  /// [rawText] 原始语音转文字或手动输入的口语化内容
  /// [type] 病历类型（入院记录/首次病程/日常病程/手术记录）
  Future<String> generateMedicalRecord(
    String rawText,
    String type, {
    required String apiKey,
  }) async {
    if (rawText.trim().isEmpty) {
      throw ArgumentError('原始文本不能为空');
    }

    final prompt = _buildGeneratePrompt(rawText, type);
    return await _callTextApi(prompt, apiKey);
  }

  /// 识别图片内容（检验单、手写笔记等）
  /// [imagePath] 本地图片路径
  Future<String> recognizeImage(
    String imagePath, {
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError('请先在设置中配置阿里云 API Key');
    }

    // 读取图片并转 base64
    final imageBytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(imageBytes);

    final data = {
      'model': 'qwen-vl-max',
      'input': {
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'image': 'data:image/jpeg;base64,$base64Image',
              },
              {
                'text':
                    '请识别这张图片中的所有文字内容。如果是检验报告单，请按项目名称、结果、参考范围分条输出；如果是手写病历笔记，请尽量识别原文并按段落整理输出。直接输出识别结果，不要附加解释。',
              },
            ],
          },
        ],
      },
      'parameters': {
        'result_format': 'message',
      },
    };

    try {
      final response = await _dio.post(
        _vlBaseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: data,
      );
      return _extractVLOutput(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 解析病历照片（纸质/屏幕混合场景）
  /// 使用 qwen-vl-max 模型，完整提取结构化病历内容
  Future<String> parseMedicalRecordImage(
    String imagePath, {
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError('请先在设置中配置阿里云 API Key');
    }

    final imageBytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(imageBytes);

    final prompt = '''
这是一张病历照片，可能是电脑屏幕上的电子病历，也可能是纸质病历的拍照。请仔细识别并完整提取其中的结构化病历内容。

识别要求：
1. 尽量提取所有可见的文字信息，包括患者信息、主诉、现病史、既往史、体格检查、辅助检查、诊断、医嘱、用药等
2. 以纯文本格式输出，段落分明，使用数字序号分条
3. 若图片模糊或文字不清晰，标注 [无法识别]
4. 若能识别出病历类型（入院记录/病程记录/手术记录等），请在开头注明
5. 对于检验检查结果，尽量按项目名称、结果、参考范围分条整理
6. 保持客观，不编造未识别出的信息
7. 注意区分屏幕截图和纸质照片的不同排版特点，灵活适配

请直接输出识别结果，不要附加解释说明。
''';

    final data = {
      'model': 'qwen-vl-max',
      'input': {
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'image': 'data:image/jpeg;base64,$base64Image',
              },
              {
                'text': prompt,
              },
            ],
          },
        ],
      },
      'parameters': {
        'result_format': 'message',
      },
    };

    try {
      final response = await _dio.post(
        _vlBaseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: data,
      );
      return _extractVLOutput(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 解析检验检查结果照片
  /// 使用 qwen-vl-max 模型，提取检验报告中的结构化数据
  Future<String> parseLabResultImage(
    String imagePath, {
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError('请先在设置中配置阿里云 API Key');
    }

    final imageBytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(imageBytes);

    final prompt = '''
这是一张检验检查结果报告的照片，可能是电脑屏幕截图或纸质报告的拍照。请仔细识别并完整提取其中的检验检查数据。

识别要求：
1. 尽量提取所有可见的检验项目信息，包括项目名称、结果、参考范围、单位、异常标志（↑/↓）等
2. 以纯文本格式输出，使用以下格式：
   【报告标题】（如：血常规、肝功能、生化全套等）
   【检验日期】（如能识别）
   1. 项目名称：结果 参考范围（异常项标注↑或↓）
   2. ...
3. 若图片模糊或文字不清晰，标注[无法识别]
4. 对于多个检验项目分组的情况，按组分类输出
5. 注意区分不同检验报告的排版特点，灵活适配
6. 如有诊断建议或备注信息，也请一并提取

请直接输出识别结果，不要附加解释说明。
''';

    final data = {
      'model': 'qwen-vl-max',
      'input': {
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'image': 'data:image/jpeg;base64,$base64Image',
              },
              {
                'text': prompt,
              },
            ],
          },
        ],
      },
      'parameters': {
        'result_format': 'message',
      },
    };

    try {
      final response = await _dio.post(
        _vlBaseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: data,
      );
      return _extractVLOutput(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 从OCR文本中匹配患者姓名
  /// 返回匹配到的患者姓名，未匹配返回null
  String? matchPatientFromText(String text, List<String> patientNames) {
    for (final name in patientNames) {
      if (name.length >= 2 && text.contains(name)) {
        return name;
      }
    }
    return null;
  }

  /// 测试 API Key 是否有效
  /// 返回 true 表示连接成功，失败则抛出异常
  Future<bool> testConnection(String apiKey) async {
    if (apiKey.isEmpty) {
      throw ArgumentError('API Key 不能为空');
    }

    final data = {
      'model': 'qwen-turbo',
      'input': {
        'messages': [
          {'role': 'user', 'content': '你好，请回复"连接成功"'},
        ],
      },
      'parameters': {
        'result_format': 'message',
        'max_tokens': 20,
      },
    };

    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
        data: data,
      );
      final result = _extractOutput(response.data);
      return result.isNotEmpty;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 语音转文字（阿里云 Paraformer）
  /// [audioPath] 本地音频文件路径
  /// 返回识别后的文字内容
  Future<String> speechToText(
    String audioPath, {
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError('请先在设置中配置阿里云 API Key');
    }

    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('音频文件不存在');
    }

    try {
      const model = 'paraformer-v2';

      // 1. 上传音频文件获取临时OSS URL
      final ossUrl = await _uploadAudioToDashScope(
        audioPath,
        apiKey: apiKey,
        model: model,
      );

      // 2. 提交异步识别任务
      final taskId = await _submitAsrTask(
        ossUrl,
        apiKey: apiKey,
        model: model,
      );

      // 3. 轮询任务状态并获取结果
      final transcriptionUrl = await _pollAsrResult(
        taskId,
        apiKey: apiKey,
      );

      // 4. 下载并解析识别结果
      final text = await _downloadAndParseTranscription(transcriptionUrl);

      return text;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('语音识别超时，请重试');
      }
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;
      String message = '网络错误';
      if (data != null && data is Map && data['message'] != null) {
        message = data['message'].toString();
      } else if (e.message != null) {
        message = e.message!;
      }
      throw Exception('语音识别失败($statusCode)：$message');
    } catch (e) {
      rethrow;
    }
  }

  /// 上传音频文件到DashScope临时存储，返回 oss:// 格式的URL
  Future<String> _uploadAudioToDashScope(
    String audioPath, {
    required String apiKey,
    required String model,
  }) async {
    // 1. 获取上传凭证
    final policyResponse = await _dio.get(
      _uploadPolicyUrl,
      queryParameters: {
        'action': 'getPolicy',
        'model': model,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (policyResponse.statusCode != 200) {
      throw Exception('获取上传凭证失败');
    }

    final policyData = policyResponse.data['data'] as Map<String, dynamic>;
    final uploadHost = policyData['upload_host'] as String;
    final uploadDir = policyData['upload_dir'] as String;
    final ossAccessKeyId = policyData['oss_access_key_id'] as String;
    final signature = policyData['signature'] as String;
    final policy = policyData['policy'] as String;
    final xOssObjectAcl = policyData['x_oss_object_acl'] as String;
    final xOssForbidOverwrite = policyData['x_oss_forbid_overwrite'] as String;

    final fileName = audioPath.split(Platform.pathSeparator).last;
    final key = '$uploadDir/$fileName';

    // 2. 上传文件到OSS
    final formData = FormData.fromMap({
      'OSSAccessKeyId': ossAccessKeyId,
      'Signature': signature,
      'policy': policy,
      'x-oss-object-acl': xOssObjectAcl,
      'x-oss-forbid-overwrite': xOssForbidOverwrite,
      'key': key,
      'success_action_status': '200',
      'file': await MultipartFile.fromFile(audioPath, filename: fileName),
    });

    final uploadResponse = await _dio.post(
      uploadHost,
      data: formData,
      options: Options(
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (uploadResponse.statusCode != 200) {
      throw Exception('文件上传失败');
    }

    return 'oss://$key';
  }

  /// 提交语音识别任务，返回任务ID
  Future<String> _submitAsrTask(
    String ossUrl, {
    required String apiKey,
    required String model,
  }) async {
    final data = {
      'model': model,
      'input': {
        'file_urls': [ossUrl],
      },
      'parameters': {
        'channel_id': [0],
        'language_hints': ['zh', 'en'],
      },
    };

    final response = await _dio.post(
      _asrUrl,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'X-DashScope-Async': 'enable',
          'X-DashScope-OssResourceResolve': 'enable',
        },
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
      data: data,
    );

    if (response.statusCode == 200) {
      final output = response.data['output'] as Map<String, dynamic>;
      final taskId = output['task_id'] as String;
      return taskId;
    }

    throw Exception('提交识别任务失败');
  }

  /// 轮询任务状态，返回识别结果下载URL
  Future<String> _pollAsrResult(
    String taskId, {
    required String apiKey,
  }) async {
    const maxRetries = 60;
    const pollInterval = Duration(seconds: 2);

    for (var i = 0; i < maxRetries; i++) {
      await Future.delayed(pollInterval);

      final response = await _dio.post(
        '$_taskUrl/$taskId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final output = response.data['output'] as Map<String, dynamic>;
        final taskStatus = output['task_status'] as String;

        if (taskStatus == 'SUCCEEDED') {
          final results = output['results'] as List;
          if (results.isNotEmpty) {
            final result = results[0] as Map<String, dynamic>;
            final subtaskStatus = result['subtask_status'] as String;
            if (subtaskStatus == 'SUCCEEDED') {
              return result['transcription_url'] as String;
            } else {
              throw Exception('识别子任务失败');
            }
          }
          throw Exception('识别结果为空');
        } else if (taskStatus == 'FAILED') {
          throw Exception('识别任务失败');
        }
      }
    }

    throw Exception('识别超时，请重试');
  }

  /// 下载识别结果并解析出文本
  Future<String> _downloadAndParseTranscription(String url) async {
    final response = await _dio.get(
      url,
      options: Options(
        responseType: ResponseType.json,
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final transcripts = data['transcripts'] as List;
      if (transcripts.isNotEmpty) {
        final transcript = transcripts[0] as Map<String, dynamic>;
        final text = transcript['text'] as String?;
        if (text != null && text.isNotEmpty) {
          return text.trim();
        }
      }
      return '';
    }

    throw Exception('下载识别结果失败');
  }

  /// 润色已有病历内容，规范医学术语
  /// [content] 原始病历内容
  Future<String> polishContent(
    String content, {
    required String apiKey,
  }) async {
    if (content.trim().isEmpty) {
      throw ArgumentError('内容不能为空');
    }

    final prompt = '''
你是一名专业的医学文案编辑，负责对病历内容进行规范化润色。

任务要求：
1. 保持原文核心内容和事实不变，不得编造或修改病情
2. 规范医学术语，修正口语化表达
3. 修正错别字、语病和标点符号
4. 调整段落结构，使条理更清晰
5. 确保符合国内《病历书写基本规范》

待润色内容：
$content

请直接输出润色后的纯文本内容，段落分明，不要附加解释说明。
''';

    return await _callTextApi(prompt, apiKey);
  }

  /// 构建病历生成 Prompt
  String _buildGeneratePrompt(String rawText, String type) {
    final typeSpec = _getTypeSpecification(type);
    return '''
你是一名专业的临床医师助手，请根据以下口语化描述，生成一份规范的$type。

【病历书写规范要求】
1. 严格按照国内《病历书写基本规范》格式输出
2. 使用标准医学术语，避免口语化表达
3. 客观、真实、准确，不编造未提及的信息
4. 对缺失的必要项目标注「未记录」或留空
5. 时间统一使用「YYYY-MM-DD HH:MM」格式（如具体时间未提及则标注日期）

【$type 结构要求】
$typeSpec
【原始描述】
$rawText

请直接输出完整的病历内容，使用纯文本格式，段落分明，不要附加其他解释性文字。
''';
  }

  /// 获取各类型病历的结构说明
  String _getTypeSpecification(String type) {
    switch (type) {
      case '入院记录':
        return '''
1. 一般情况（姓名、性别、年龄、科室、床号、入院日期）
2. 主诉
3. 现病史
4. 既往史
5. 个人史/婚育史/家族史（如提及）
6. 体格检查（生命体征、各系统检查）
7. 辅助检查结果
8. 初步诊断
9. 诊疗计划
''';
      case '首次病程记录':
        return '''
1. 病例特点（简要概括）
2. 初步诊断及依据
3. 鉴别诊断
4. 诊疗计划
''';
      case '日常病程':
        return '''
1. 今日患者主诉及一般情况
2. 病情变化（症状、体征）
3. 重要检查结果及分析
4. 诊疗措施执行情况
5. 下一步诊疗计划
6. 医师签名
''';
      case '手术记录':
        return '''
1. 手术日期、时间
2. 术前诊断
3. 术中诊断
4. 手术名称
5. 手术医师、助手、麻醉方式
6. 手术经过（体位、切口、探查、手术步骤、出血量等）
7. 术中出血、输血、输液情况
8. 标本处理
9. 术后处理
10. 医师签名
''';
      default:
        return '''
1. 时间
2. 主要内容
3. 医师签名
''';
    }
  }

  /// 调用文本生成 API
  Future<String> _callTextApi(String prompt, String apiKey) async {
    if (apiKey.isEmpty) {
      throw StateError('请先在设置中配置阿里云 API Key');
    }

    final data = {
      'model': 'qwen-turbo',
      'input': {
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
      'parameters': {
        'result_format': 'message',
        'top_p': 0.8,
        'temperature': 0.7,
      },
    };

    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: data,
      );
      return _extractOutput(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 从文本 API 响应中提取输出
  String _extractOutput(dynamic data) {
    try {
      final output = data['output'];
      final choices = output['choices'] as List;
      final message = choices[0]['message'];
      return message['content'] as String;
    } catch (e) {
      return 'AI 响应解析失败：${data.toString()}';
    }
  }

  /// 从多模态 API 响应中提取输出
  String _extractVLOutput(dynamic data) {
    try {
      final output = data['output'];
      final choices = output['choices'] as List;
      final message = choices[0]['message'];
      final content = message['content'] as List;
      return content[0]['text'] as String;
    } catch (e) {
      return 'AI 响应解析失败：${data.toString()}';
    }
  }

  /// 处理 Dio 错误
  Exception _handleDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    String message = 'AI 服务请求失败';

    if (statusCode == 401) {
      message = 'API Key 无效，请检查设置中的阿里云 API Key';
    } else if (statusCode == 429) {
      message = '请求过于频繁，请稍后再试';
    } else if (statusCode == 500) {
      message = 'AI 服务内部错误，请稍后重试';
    } else if (data != null && data['message'] != null) {
      message = data['message'].toString();
    } else if (e.error != null) {
      message = '网络错误：${e.error}';
    }

    return Exception(message);
  }
}
