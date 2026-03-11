import 'package:rust_assistant/databeans/unit_ref.dart';
import 'package:rust_assistant/file_type_checker.dart';
import 'package:rust_assistant/global_depend.dart';
import 'package:sprintf/sprintf.dart';

import 'databeans/visual_analytics_result.dart';

import 'file_operator/file_operator.dart';
import 'l10n/app_localizations.dart';
import 'mod/line_parser.dart';

class ProjectAnalyzer {
  String rootPath;
  FileSystemOperator fileSystemOperator;
  bool _isRunning = false;
  VisualAnalyticsResult? _lastResult;
  final List<UnitRef> unitRefList = List.empty(growable: true);
  Map<String, DateTime> modificationTime = {};
  Map<String, List<ListDataTask>> pathToListData = {};

  ProjectAnalyzer(this.rootPath, this.fileSystemOperator);

  VisualAnalyticsResult? get lastResult => _lastResult;

  Future<void> analyze(
    AppLocalizations appLocalizations,
    Function? onStart,
    bool Function(int, int, String)? progress,
    Function(VisualAnalyticsResult? result)? onFinish,
  ) async {
    if (_isRunning) {
      return;
    }
    _isRunning = true;
    if (!await fileSystemOperator.isDir(rootPath)) {
      return;
    }
    var result = VisualAnalyticsResult();
    result.startTime = DateTime.now();
    onStart?.call();
    List<UnitRef> temporary = List.empty(growable: true);
    var fileVisualAnalytics = VisualAnalyticsResultItem();
    var assetsVisualAnalytics = VisualAnalyticsResultItem();
    var memoryVisualAnalytics = VisualAnalyticsResultItem();
    var tagVisualAnalytics = VisualAnalyticsResultItem();
    var unitVisualAnalytics = VisualAnalyticsResultItem();
    fileVisualAnalytics.title = appLocalizations.file;
    assetsVisualAnalytics.title = appLocalizations.assets;
    memoryVisualAnalytics.title = appLocalizations.memory;
    tagVisualAnalytics.title = appLocalizations.tags;
    unitVisualAnalytics.title = appLocalizations.unit;
    int index = 0;
    Set<String> tagSet = {};
    var languageDisplayText =
        "displayText_${HiveHelper.get(HiveHelper.language)}".toLowerCase();
    List<String> pathList = [];
    await fileSystemOperator.list(rootPath, (path) async {
      if (await fileSystemOperator.isDir(path)) {
        return false;
      }
      if (progress?.call(
            -1,
            pathList.length,
            sprintf(appLocalizations.countFiles, [pathList.length + 1]),
          ) ==
          true) {
        return true;
      }
      pathList.add(path);
      return false;
    }, recursive: true);
    for (int i = 0; i < pathList.length; i++) {
      String path = pathList[i];
      index++;
      var relativePath = await fileSystemOperator.relative(path, rootPath);
      if (progress?.call(
            index,
            pathList.length,
            sprintf(appLocalizations.indexIsBeingUpdated, [relativePath]),
          ) ==
          true) {
        break;
      }
      var time = await fileSystemOperator.getModifiedTime(path);
      if (modificationTime.containsKey(path)) {
        if (modificationTime[path] == time) {
          //The time remains the same. Data is loaded from the memory.
          //时间没变，从内存中加载数据。
          var listDataTasks = pathToListData[path];
          if (listDataTasks != null) {
            for (var value in listDataTasks) {
              if (value.taskType == null) {
                continue;
              }
              if (value.taskType == TaskType.AddFile) {
                fileVisualAnalytics.result.add(value.listData!);
                continue;
              }
              if (value.taskType == TaskType.AddAssets) {
                assetsVisualAnalytics.result.add(value.listData!);
                continue;
              }
              if (value.taskType == TaskType.AddAudio) {
                assetsVisualAnalytics.result.add(value.listData!);
                continue;
              }
              if (value.taskType == TaskType.AddTag) {
                tagVisualAnalytics.result.add(value.listData!);
                continue;
              }
              if (value.taskType == TaskType.AddUnit) {
                unitVisualAnalytics.result.add(value.listData!);
                continue;
              }
              if (value.taskType == TaskType.AddMemory) {
                memoryVisualAnalytics.result.add(value.listData!);
                continue;
              }
            }
          }
          continue;
        }
      }
      List<ListDataTask> tasks = List.empty(growable: true);
      pathToListData[path] = tasks;
      modificationTime[path] = time!;
      var fileHead = await FileTypeChecker.readFileHeader(path);
      var fileType = FileTypeChecker.getFileType(path, fileHeader: fileHead);
      var fileListData = ListData();
      fileListData.title = await fileSystemOperator.name(path);
      fileListData.subTitle = relativePath;
      fileListData.path = path;
      ListDataTask listDataTask = ListDataTask();
      listDataTask.listData = fileListData;
      listDataTask.taskType = TaskType.AddFile;
      tasks.add(listDataTask);
      fileVisualAnalytics.result.add(fileListData);
      if (fileType == FileTypeChecker.FileTypeUnknown) {
        continue;
      }
      if (fileType == FileTypeChecker.FileTypeImage) {
        fileListData.bytes = await fileSystemOperator.readAsBytes(path);
        ListDataTask listDataTask = ListDataTask();
        listDataTask.listData = fileListData;
        listDataTask.taskType = TaskType.AddAssets;
        tasks.add(listDataTask);
        assetsVisualAnalytics.result.add(fileListData);
        continue;
      }
      if (fileType == FileTypeChecker.FileTypeAudio) {
        ListDataTask listDataTask = ListDataTask();
        listDataTask.listData = fileListData;
        listDataTask.taskType = TaskType.AddAudio;
        tasks.add(listDataTask);
        assetsVisualAnalytics.result.add(fileListData);
        continue;
      }
      if (fileType == FileTypeChecker.FileTypeArchive) {
        continue;
      }
      UnitRef unitRef = UnitRef();
      unitRef.path = path;
      var text = await fileSystemOperator.readAsString(path) ?? "";
      var lineParser = LineParser(text);
      String? section;
      while (true) {
        var line = lineParser.nextLine();
        if (line == null) {
          break;
        }
        if (line.startsWith("[") && line.endsWith("]")) {
          section = GlobalDepend.getSectionPrefix(line);
          continue;
        }
        var lineLowerCase = line.toLowerCase();
        if (lineLowerCase.contains("memory")) {
          var memoryListData = ListData();
          memoryListData.title = line;
          memoryListData.subTitle = relativePath;
          memoryListData.path = path;
          memoryVisualAnalytics.result.add(memoryListData);
          ListDataTask listDataTask = ListDataTask();
          listDataTask.listData = memoryListData;
          listDataTask.taskType = TaskType.AddMemory;
          tasks.add(listDataTask);
        }
        var symbol = lineLowerCase.indexOf(':');
        if (symbol > -1) {
          var keyName = lineLowerCase.substring(0, symbol);
          if (keyName == "tags") {
            var tagListData = ListData();
            tagListData.title = line;
            tagListData.subTitle = relativePath;
            tagListData.path = path;
            ListDataTask listDataTask = ListDataTask();
            listDataTask.listData = tagListData;
            listDataTask.taskType = TaskType.AddTag;
            tasks.add(listDataTask);
            tagVisualAnalytics.result.add(tagListData);
            var value = line.substring(symbol + 1).trim();
            var valueList = value.split(',');
            for (var tag in valueList) {
              var tgaTrim = tag.trim();
              if (!tagSet.contains(tgaTrim)) {
                tagSet.add(tgaTrim);
              }
            }
          } else if (section == "core" && keyName == "name") {
            unitRef.name = line.substring(symbol + 1).trim();
          } else if (unitRef.displayName == null &&
              section == "core" &&
              keyName == "displaytext") {
            unitRef.displayName = line.substring(symbol + 1).trim();
          } else if (section == "core" && keyName == languageDisplayText) {
            unitRef.displayName = line.substring(symbol + 1).trim();
          }
        }
      }
      if (unitRef.name != null) {
        temporary.add(unitRef);
        var unitData = ListData();
        unitData.title = unitRef.name;
        unitData.subTitle = relativePath;
        unitData.path = path;
        ListDataTask listDataTask = ListDataTask();
        listDataTask.listData = unitData;
        listDataTask.taskType = TaskType.AddUnit;
        tasks.add(listDataTask);
        unitVisualAnalytics.result.add(unitData);
      }
    }
    result.items.add(fileVisualAnalytics);
    result.items.add(assetsVisualAnalytics);
    result.items.add(memoryVisualAnalytics);
    result.items.add(tagVisualAnalytics);
    result.items.add(unitVisualAnalytics);
    unitRefList.clear();
    unitRefList.addAll(temporary);
    result.tagList = tagSet.toList();
    result.endTime = DateTime.now();
    _lastResult = result;
    _isRunning = false;
    onFinish?.call(result);
  }
}
