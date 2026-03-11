//可视化分析结果
import 'dart:convert';
import 'dart:typed_data';

class VisualAnalyticsResult {
  //分析开始时间
  DateTime? startTime;

  //分析结束时间
  DateTime? endTime;
  List<VisualAnalyticsResultItem> items = List.empty(growable: true);
  List<String> tagList = List.empty();
}

class VisualAnalyticsResultItem {
  //分析结果
  List<ListData> result = List.empty(growable: true);

  //分析结果标题
  String? title;
}

class ListData {
  String? title;
  String? subTitle;
  String? path;

  Map<String, dynamic> toJson() {
    return {'title': title, 'subTitle': subTitle, 'path': path};
  }

  static ListData fromJson(Map<String, dynamic> json) {
    return ListData()
      ..title = json['title']
      ..subTitle = json['subTitle']
      ..path = json['path'];
  }
}

enum TaskType { AddFile, AddAssets, AddAudio, AddTag, AddUnit, AddMemory }

class ListDataTask {
  ListData? listData;
  TaskType? taskType;

  // 序列化
  Map<String, dynamic> toJson() {
    return {
      'listData': listData?.toJson(),
      // 枚举转字符串（如 TaskType.AddFile → "AddFile"）
      'taskType': taskType?.name,
    };
  }

  // 反序列化
  static ListDataTask fromJson(Map<String, dynamic> json) {
    return ListDataTask()
      ..listData = json['listData'] != null
          ? ListData.fromJson(json['listData'])
          : null
      // 字符串转回枚举（如 "AddFile" → TaskType.AddFile）
      ..taskType = json['taskType'] != null
          ? TaskType.values.firstWhere((e) => e.name == json['taskType'])
          : null;
  }
}
