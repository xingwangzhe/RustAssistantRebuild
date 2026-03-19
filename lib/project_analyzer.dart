import 'dart:convert';

import 'package:rust_assistant/databeans/unit_ref.dart';
import 'package:rust_assistant/file_type_checker.dart';
import 'package:rust_assistant/global_depend.dart';
import 'package:sprintf/sprintf.dart';

import 'constant.dart';
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
  Map<String, List<ProblemItem>> problemItemListData = {};
  Map<String, UnitRef> pathToUnitRef = {};
  bool first = true;

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
    String folderName = await fileSystemOperator.name(rootPath);
    String configPath = fileSystemOperator.join(
      fileSystemOperator.join(
        await GlobalDepend.getUserDataFolder() ?? rootPath,
        "cache",
      ),
      folderName,
    );
    await fileSystemOperator.mkdir(
      fileSystemOperator.join(
        await GlobalDepend.getUserDataFolder() ?? rootPath,
        "cache",
      ),
      folderName,
    );
    String modificationTimeJsonPath = fileSystemOperator.join(
      configPath,
      "timeIndex.json",
    );
    String listDataJsonPath = fileSystemOperator.join(
      configPath,
      "listData.json",
    );
    String problemItemJsonPath = fileSystemOperator.join(
      configPath,
      "problemItem.json",
    );
    String unitRefPath = fileSystemOperator.join(configPath, "unitRefs.json");
    if (progress?.call(-1, 0, appLocalizations.readCache) == true) {
      return;
    }
    if (modificationTime.isEmpty &&
        await fileSystemOperator.exist(modificationTimeJsonPath)) {
      String? modificationTimeJson = await fileSystemOperator.readAsString(
        modificationTimeJsonPath,
      );
      if (modificationTimeJson != null && modificationTimeJson.isNotEmpty) {
        Map<String, dynamic> timeMap = jsonDecode(modificationTimeJson);
        modificationTime = timeMap.map((key, value) {
          return MapEntry(key, DateTime.parse(value as String));
        });
      }
    }
    if (pathToListData.isEmpty &&
        await fileSystemOperator.exist(listDataJsonPath)) {
      String? listDataJson = await fileSystemOperator.readAsString(
        listDataJsonPath,
      );
      if (listDataJson != null && listDataJson.isNotEmpty) {
        Map<String, dynamic> dataMap = jsonDecode(listDataJson);
        pathToListData = dataMap.map((key, value) {
          List<ListDataTask> tasks = (value as List)
              .map(
                (item) => ListDataTask.fromJson(item as Map<String, dynamic>),
              )
              .toList();
          return MapEntry(key, tasks);
        });
      }
    }
    if (first && await fileSystemOperator.exist(problemItemJsonPath)) {
      //The first analysis requires reading data from the file.
      //第一次分析，需要从文件内读取数据。
      String? problemItem = await fileSystemOperator.readAsString(
        problemItemJsonPath,
      );
      if (problemItem != null && problemItem.isNotEmpty) {
        Map<String, dynamic> dataMap = jsonDecode(problemItem);
        problemItemListData = dataMap.map((key, value) {
          List<ProblemItem> tasks = (value as List)
              .map((item) => ProblemItem.fromJson(item as Map<String, dynamic>))
              .toList();
          return MapEntry(key, tasks);
        });
      }
    } else {
      problemItemListData.clear();
    }
    if (pathToUnitRef.isEmpty && await fileSystemOperator.exist(unitRefPath)) {
      String? unitRefData = await fileSystemOperator.readAsString(unitRefPath);
      if (unitRefData != null && unitRefData.isNotEmpty) {
        Map<String, dynamic> dataMap = jsonDecode(unitRefData);
        pathToUnitRef = dataMap.map((key, value) {
          UnitRef unitRef = UnitRef.fromJson(value);
          return MapEntry(key, unitRef);
        });
      }
    }

    first = false;
    List<UnitRef> temporaryUnitRef = List.empty(growable: true);
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
        "displayText_${HiveHelper.get(HiveHelper.language, defaultValue: Constant.defaultLanguage)}"
            .toLowerCase();
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
          List<ProblemItem>? problemList = problemItemListData[path];
          if (problemList != null) {
            for (var value in problemList) {
              result.problems.add(value);
            }
          }
          UnitRef? unitRef = pathToUnitRef[path];
          if (unitRef != null) {
            temporaryUnitRef.add(unitRef);
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
      String? fullSection;
      Set<String> repeatKeys = {};
      while (true) {
        var line = lineParser.nextLine();
        if (line == null) {
          break;
        }
        if (line.startsWith("[") && line.endsWith("]")) {
          section = GlobalDepend.getSectionPrefix(line);
          fullSection = GlobalDepend.getSection(line);
          repeatKeys.clear();
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
          if (repeatKeys.contains(keyName)) {
            //A duplicate key has been found.
            //发现重复key。
            ProblemItem problemItem = ProblemItem();
            problemItem.message = sprintf(appLocalizations.repeatKey, [
              keyName,
              fullSection ?? "null",
            ]);
            problemItem.type = ProblemType.RepeatKey;
            problemItem.path = path;
            problemItem.relativePath = relativePath;
            result.problems.add(problemItem);
            if (problemItemListData.containsKey(path)) {
              problemItemListData[path]?.add(problemItem);
            } else {
              List<ProblemItem> list = List.empty(growable: true);
              list.add(problemItem);
              problemItemListData[path] = list;
            }
          }
          repeatKeys.add(keyName);
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
        temporaryUnitRef.add(unitRef);
        pathToUnitRef[path] = unitRef;
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

    if (progress?.call(-1, 0, appLocalizations.writeCache) == true) {
      return;
    }
    if (modificationTime.isEmpty) {
      if (await fileSystemOperator.exist(modificationTimeJsonPath)) {
        await fileSystemOperator.delete(modificationTimeJsonPath);
      }
    } else {
      Map<String, String> timeJsonMap = modificationTime.map((key, value) {
        return MapEntry(key, value.toIso8601String());
      });
      String timeJsonStr = jsonEncode(timeJsonMap);
      await fileSystemOperator.writeFile(
        configPath,
        "timeIndex.json",
        timeJsonStr,
      );
    }

    if (pathToListData.isEmpty) {
      if (await fileSystemOperator.exist(listDataJsonPath)) {
        await fileSystemOperator.delete(listDataJsonPath);
      }
    } else {
      Map<String, List<Map<String, dynamic>>> dataJsonMap = pathToListData.map((
        key,
        value,
      ) {
        List<Map<String, dynamic>> tasksJson = value
            .map((task) => task.toJson())
            .toList();
        return MapEntry(key, tasksJson);
      });
      String dataJsonStr = jsonEncode(dataJsonMap);
      await fileSystemOperator.writeFile(
        configPath,
        "listData.json",
        dataJsonStr,
      );
    }

    if (problemItemListData.isEmpty) {
      if (await fileSystemOperator.exist(problemItemJsonPath)) {
        await fileSystemOperator.delete(problemItemJsonPath);
      }
    } else {
      Map<String, List<Map<String, dynamic>>> problemItemListJsonData =
          problemItemListData.map((key, value) {
            List<Map<String, dynamic>> tasksJson = value
                .map((task) => task.toJson())
                .toList();
            return MapEntry(key, tasksJson);
          });
      String problemItemListJsonStr = jsonEncode(problemItemListJsonData);
      await fileSystemOperator.writeFile(
        configPath,
        "problemItem.json",
        problemItemListJsonStr,
      );
    }

    if (pathToUnitRef.isEmpty) {
      if (await fileSystemOperator.exist(unitRefPath)) {
        await fileSystemOperator.delete(unitRefPath);
      }
    } else {
      String pathToUnitRefJsonStr = jsonEncode(pathToUnitRef);
      await fileSystemOperator.writeFile(
        configPath,
        "unitRefs.json",
        pathToUnitRefJsonStr,
      );
    }
    result.items.add(fileVisualAnalytics);
    result.items.add(assetsVisualAnalytics);
    result.items.add(memoryVisualAnalytics);
    result.items.add(tagVisualAnalytics);
    result.items.add(unitVisualAnalytics);
    unitRefList.clear();
    unitRefList.addAll(temporaryUnitRef);
    result.tagList = tagSet.toList();
    result.endTime = DateTime.now();
    _lastResult = result;
    _isRunning = false;
    onFinish?.call(result);
  }
}
