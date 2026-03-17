import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:rust_assistant/databeans/resource_ref.dart';
import 'package:rust_assistant/databeans/unit_template.dart';
import 'package:rust_assistant/file_operator/file_operator.dart';
import 'package:rust_assistant/file_type_checker.dart';
import 'package:rust_assistant/global_depend.dart';
import 'package:rust_assistant/mod/ini_reader.dart';
import 'package:rust_assistant/mod/mod.dart';
import 'package:rust_assistant/operation_dialog.dart';
import 'package:rust_assistant/pages/built_in_file_manager_page.dart';
import 'package:rust_assistant/pages/problem_dialog.dart';
import 'package:rust_assistant/pages/save_as_template_dialog.dart';
import 'package:rust_assistant/pages/work_space_page.dart';
import 'package:rust_assistant/text_difference.dart';
import 'package:sprintf/sprintf.dart';
import 'package:window_manager/window_manager.dart';

import '../constant.dart';
import '../create_file_of_folder_dialog.dart';
import '../databeans/runtime_file_info.dart';
import '../databeans/visual_analytics_result.dart';
import '../l10n/app_localizations.dart';
import '../progress_info.dart';
import '../project_analyzer.dart';
import 'analytics_dialog.dart';
import 'management_template_page.dart';

class EditUnitsPage extends StatefulWidget {
  const EditUnitsPage({super.key, required this.mod});

  final Mod mod;

  @override
  State<StatefulWidget> createState() {
    return _EditUnitsPageState();
  }
}

enum CloseTagType {
  CLOSE_SELF,
  CLOSE_OTHER,
  CLOSE_ALL,
  CLOSE_LEFT,
  CLOSE_RIGHT,
}

class _EditUnitsPageState extends State<EditUnitsPage>
    with WidgetsBindingObserver, WindowListener {
  final FocusNode _focusNode = FocusNode();
  final List<String> _openedFilePath = List.empty(growable: true);
  final List<String> _unsavedFilePath = List.empty(growable: true);
  final List<ResourceRef> _globalResource = List.empty(growable: true);
  String? _currentPath;
  final Map<String, RuntimeFileInfo> _pathToRuntimeFileInfo = {};
  int _targetTabIndex = 0;
  late ProjectAnalyzer _projectAnalyzer;
  final ValueNotifier<ProgressInfo> _progressInfoNotifier = ValueNotifier(
    ProgressInfo(value: -1, message: null, analysis: false),
  );
  bool _displayLineNumber = false;
  bool _displayOperationOptions = true;
  final FileSystemOperator _fileSystemOperator =
      GlobalDepend.getFileSystemOperator();
  bool _firstDid = true;
  String? _updateIndexStart;
  String? _ready;
  bool _cancelAnalytics = false;
  List<String> _tagList = List.empty();
  bool _autoSave = true;
  bool _showLeftWidget = true;
  bool _restoreOpenedFile = true;
  bool _automaticIndexConstruction = !Platform.isAndroid;
  DateTime? _lastProgressUpdateTime;
  final Duration _throttleDuration = const Duration(milliseconds: 500);

  //Reload all the open files after the analysis.
  //重新加载所有打开的文件在分析后。
  bool reloadAllOpenedFileAfterAnalyze = false;

  @override
  void initState() {
    super.initState();
    if (HiveHelper.containsKey(HiveHelper.automaticIndexConstruction)) {
      _automaticIndexConstruction = HiveHelper.get(
        HiveHelper.automaticIndexConstruction,
        defaultValue: !Platform.isAndroid,
      );
    }
    if (HiveHelper.containsKey(HiveHelper.autoSave)) {
      _autoSave = HiveHelper.get(HiveHelper.autoSave, defaultValue: true);
    }
    if (HiveHelper.containsKey(HiveHelper.displayOperationOptions)) {
      _displayOperationOptions = HiveHelper.get(
        HiveHelper.displayOperationOptions,
      );
    }
    if (HiveHelper.containsKey(HiveHelper.toggleLineNumber)) {
      _displayLineNumber = HiveHelper.get(HiveHelper.toggleLineNumber);
    }
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    _projectAnalyzer = ProjectAnalyzer(
      widget.mod.path,
      GlobalDepend.getFileSystemOperator(),
    );
    if (HiveHelper.containsKey(HiveHelper.restoreOpenedFile)) {
      _restoreOpenedFile = HiveHelper.get(HiveHelper.restoreOpenedFile);
    }
    loadGlobalRes();
    loadOpenedFile();
  }

  void loadOpenedFile() async {
    if (!_restoreOpenedFile) {
      return;
    }
    String? dataFolder = await GlobalDepend.getUserDataFolder();
    if (dataFolder == null) {
      return;
    }
    String rootName = await _fileSystemOperator.name(widget.mod.path);
    String modCache = _fileSystemOperator.join(
      _fileSystemOperator.join(dataFolder, "cache"),
      rootName,
    );
    _fileSystemOperator.mkdir(
      _fileSystemOperator.join(dataFolder, "cache"),
      rootName,
    );
    String openedFileJson = _fileSystemOperator.join(
      modCache,
      "openedFile.json",
    );
    if (await _fileSystemOperator.exist(openedFileJson)) {
      String? jsonContent = await _fileSystemOperator.readAsString(
        openedFileJson,
      );
      if (jsonContent == null || jsonContent.isEmpty) {
        return;
      }

      dynamic jsonData = jsonDecode(jsonContent);
      if (jsonData is List) {
        for (var value in jsonData.whereType<String>().toList()) {
          _onRequestOpenFile(value, false);
        }
      }
    }
  }

  void saveOpenedFile() async {
    if (!_restoreOpenedFile) {
      return;
    }
    String? dataFolder = await GlobalDepend.getUserDataFolder();
    if (dataFolder == null) {
      return;
    }
    String rootName = await _fileSystemOperator.name(widget.mod.path);
    String modCache = _fileSystemOperator.join(
      _fileSystemOperator.join(dataFolder, "cache"),
      rootName,
    );
    String jsonContent = jsonEncode(_openedFilePath);
    await _fileSystemOperator.writeFile(
      modCache,
      "openedFile.json",
      jsonContent,
    );
  }

  void _doAnalyze(BuildContext buildContext) {
    _projectAnalyzer.analyze(
      AppLocalizations.of(buildContext)!,
      _onStartAnalyze,
      _progress,
      _onFinishAnalyze,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    //在安卓平台，显示/隐藏软键盘会调用didChangeDependencies方法
    if (_firstDid) {
      _firstDid = false;
      _updateIndexStart = AppLocalizations.of(context)!.updateIndexStart;
      _ready = AppLocalizations.of(context)!.ready;
      if (_automaticIndexConstruction) {
        _doAnalyze(context);
      }
    }
  }

  void loadGlobalRes() async {
    var allUnitsTemplate = p.join(widget.mod.path, Constant.allUnitsTemplate);
    bool allUnitsExists =
        await FileSystemEntity.type(allUnitsTemplate) !=
        FileSystemEntityType.notFound;
    setState(() {
      _globalResource.clear();
    });
    if (allUnitsExists) {
      IniReader allUnitsReader = IniReader(
        await File(allUnitsTemplate).readAsString(),
      );
      var allSection = allUnitsReader.getAllSection();
      if (allSection.isEmpty) {
        return;
      }
      for (var sectionName in allSection) {
        var finalContext = context;
        var name = GlobalDepend.getSectionPrefix(sectionName).toLowerCase();
        if (name == "global_resource" || name == "resource") {
          if (!finalContext.mounted) {
            return;
          }
          var last = GlobalDepend.getSectionSuffix(sectionName);
          var language = GlobalDepend.getLanguage(finalContext);
          String? displayName = allUnitsReader
              .getKeyValueFromSection(sectionName, "displayName_$language")
              ?.value;
          displayName ??= allUnitsReader
              .getKeyValueFromSection(sectionName, "displayName")
              ?.value;
          if (last.isNotEmpty) {
            setState(() {
              _globalResource.add(
                ResourceRef(
                  name: last,
                  path: allUnitsTemplate,
                  globalResource: name == "global_resource",
                  displayName: displayName,
                ),
              );
            });
          }
        }
      }
    }
  }

  Future<bool> _performSave() async {
    if (_openedFilePath.isEmpty) return false;
    final nowOpenedPath = _openedFilePath[_targetTabIndex];
    if (!_unsavedFilePath.contains(nowOpenedPath)) {
      return false;
    }
    final runtimeFileInfo = _pathToRuntimeFileInfo[nowOpenedPath];
    if (runtimeFileInfo == null) {
      return false;
    }
    var name = runtimeFileInfo.fileName;
    if (name == null) {
      return false;
    }
    if (runtimeFileInfo.data != null) {
      await _fileSystemOperator.writeFile(
        await _fileSystemOperator.dirname(nowOpenedPath),
        name,
        runtimeFileInfo.data,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sprintf(AppLocalizations.of(context)!.fileHasBeenSaved, [name]),
          ),
        ),
      );
    }
    setState(() {
      _unsavedFilePath.remove(nowOpenedPath);
    });
    var finalContext = context;
    if (_automaticIndexConstruction && finalContext.mounted) {
      _doAnalyze(finalContext);
    }
    //额外的条件，如果保存的是allUnits
    var allUnitsTemplate = p.join(widget.mod.path, Constant.allUnitsTemplate);
    if (nowOpenedPath == allUnitsTemplate) {
      loadGlobalRes();
    }
    return true;
  }

  Future<void> _showSourceDiff() async {
    if (_openedFilePath.isEmpty) {
      return;
    }
    final nowOpenedPath = _openedFilePath[_targetTabIndex];
    final fileContent = await _fileSystemOperator.readAsString(nowOpenedPath);
    RuntimeFileInfo? runtimeFileInfo = _pathToRuntimeFileInfo[nowOpenedPath];
    if (runtimeFileInfo == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    showModalBottomSheet(
      showDragHandle: true,
      isScrollControlled: true,
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.basename(nowOpenedPath),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextDifference(
                original: fileContent ?? "",
                newText: runtimeFileInfo.data ?? fileContent ?? "",
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onRequestOpenFile(String path, bool needUpdateFile) async {
    var index = _openedFilePath.indexOf(path);
    var fileName = await _fileSystemOperator.name(path);
    var fileHeader = await FileTypeChecker.readFileHeader(path);
    var fileType = FileTypeChecker.getFileType(path, fileHeader: fileHeader);
    if (index < 0) {
      setState(() {
        _openedFilePath.add(path);
        RuntimeFileInfo fileInfo = RuntimeFileInfo();
        fileInfo.fileName = fileName;
        fileInfo.fileType = fileType;
        _pathToRuntimeFileInfo[path] = fileInfo;
        _targetTabIndex = _openedFilePath.length - 1;
      });
    } else {
      setState(() {
        _targetTabIndex = index;
      });
    }
    if (needUpdateFile) {
      saveOpenedFile();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_automaticIndexConstruction) {
        _doAnalyze(context);
      }
    } else if (state == AppLifecycleState.paused) {
      //仅限安卓和ios
      _performAutoSave();
    }
  }

  void _performAutoSave() {
    if (_autoSave) {
      _performSave();
    }
  }

  void _onFinishAnalyze(VisualAnalyticsResult? result) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (_ready != null) {
        _progressInfoNotifier.value = ProgressInfo(
          value: 1,
          message: _ready!,
          analysis: false,
        );
      }
      if (reloadAllOpenedFileAfterAnalyze && _openedFilePath.isNotEmpty) {
        for (var value in _openedFilePath) {
          if (_unsavedFilePath.contains(value)) {
            //Do not corrupt the file that the user is currently editing in the memory.
            //不要破坏内存中用户正编辑的文件。
            continue;
          }
          RuntimeFileInfo? runtimeFileInfo = _pathToRuntimeFileInfo[value];
          if (runtimeFileInfo != null) {
            //Make it reload.
            //使其重新加载。
            runtimeFileInfo.data = null;
          }
        }
      }
      //Always clear the marks.
      //永远清除标记。
      reloadAllOpenedFileAfterAnalyze = false;
      if (result != null) {
        _tagList = result.tagList;
      }
    });
  }

  void _onStartAnalyze() {
    _cancelAnalytics = false;
    setState(() {
      if (_updateIndexStart != null) {
        _progressInfoNotifier.value = ProgressInfo(
          value: -1,
          message: _updateIndexStart!,
          analysis: true,
        );
      }
    });
  }

  bool _progress(int index, int total, String message) {
    if (!mounted) {
      return true;
    }
    final now = DateTime.now();
    // 检查是否需要节流（未到执行时间则直接返回）
    if (_lastProgressUpdateTime != null &&
        now.difference(_lastProgressUpdateTime!) < _throttleDuration) {
      return _cancelAnalytics;
    }

    //达到执行时间，执行更新逻辑并记录最新时间
    _lastProgressUpdateTime = now; // 更新上次执行时间
    setState(() {
      _progressInfoNotifier.value = ProgressInfo(
        value: index == -1 ? -1 : index / total,
        message: message,
        analysis: true,
      );
    });
    return _cancelAnalytics;
  }

  //当显示操作对话框
  Future<bool> showOperationDialogBox(
    Function(String, String, bool, String, bool) onCreate, {
    String? folder,
  }) async {
    String rootFolder = widget.mod.path;
    if (folder != null) {
      rootFolder = folder;
    }
    return await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return OperationDialog(
          folder: rootFolder,
          isRoot: rootFolder == widget.mod.path,
          onCreateNewFile: () async {
            await showCreateFileOrFolderDialog(onCreate, folder: rootFolder);
          },
          onCreateModInfo: () async {
            await _doCreateFile(
              GlobalDepend.getFileSystemOperator().join(
                rootFolder,
                Constant.modInfoFileName,
              ),
              false,
              Constant.modInfoFileName,
              true,
              null,
              rootFolder,
              Constant.modInfoFileName,
              onCreate,
            );
          },
          onCreateAllUnitsTemplate: () async {
            await _doCreateFile(
              GlobalDepend.getFileSystemOperator().join(
                rootFolder,
                Constant.allUnitsTemplate,
              ),
              false,
              Constant.allUnitsTemplate,
              true,
              null,
              rootFolder,
              Constant.allUnitsTemplate,
              onCreate,
            );
          },
        );
      },
    );
  }

  Future<void> showCreateFileOrFolderDialog(
    Function(String, String, bool, String, bool) onCreate, {
    String? folder,
  }) async {
    String rootFolder = widget.mod.path;
    if (folder != null) {
      rootFolder = folder;
    }
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateFileOfFolderDialog(
        folder: rootFolder,
        onCreate:
            (
              path,
              asFolder,
              fileName,
              createdFromUnitTemplate,
              templates,
              inputText,
            ) async {
              await _doCreateFile(
                path,
                asFolder,
                fileName,
                createdFromUnitTemplate,
                templates,
                rootFolder,
                inputText,
                onCreate,
              );
            },
      ),
    );
  }

  Future<void> _doCreateFile(
    String path,
    bool asFolder,
    String fileName,
    bool createdFromUnitTemplate,
    Templates? templates,
    String rootFolder,
    String inputText,
    Function(String, String, bool, String, bool) onCreate,
  ) async {
    final FileSystemOperator fileSystemOperator =
        GlobalDepend.getFileSystemOperator();
    if (asFolder) {
      await fileSystemOperator.mkdir(rootFolder, fileName);
    } else {
      final StringBuffer stringBuffer = StringBuffer();
      if (createdFromUnitTemplate) {
        var unitName = fileName;
        var symbolIndex = fileName.lastIndexOf(".");
        if (symbolIndex > 0) {
          unitName = fileName.substring(0, symbolIndex);
        }
        if (fileName.toLowerCase() == Constant.modInfoFileName) {
          var folderName = await fileSystemOperator.name(rootFolder);
          stringBuffer.write("[mod]\ntitle: ");
          stringBuffer.write(folderName);
          stringBuffer.write("\nminVersion:1.13");
        } else if (fileName.toLowerCase() == Constant.allUnitsTemplate) {
          stringBuffer.write("[core]");
        } else if (templates != null) {
          var inputName = inputText;
          var symbolIndex = inputName.lastIndexOf('.');
          if (symbolIndex > -1) {
            inputName = inputName.substring(0, symbolIndex);
          }
          var path = templates.path;
          if (path != null) {
            if (templates.custom) {
              String? data = await fileSystemOperator.readAsString(path);
              if (data != null) {
                stringBuffer.write(data);
              }
            } else {
              var templatesData = await rootBundle.loadString(path);
              stringBuffer.write(
                templatesData
                    .replaceAll("{UNIT_NAME}", unitName)
                    .replaceAll("{INPUT_NAME}", inputName),
              );
            }
          }
        }
      }
      //不要动这里，必须调用写文件的方法
      await fileSystemOperator.writeFile(
        rootFolder,
        fileName,
        stringBuffer.toString(),
      );
      var finalContext = context;
      if (_automaticIndexConstruction && finalContext.mounted) {
        _doAnalyze(finalContext);
      }
    }
    onCreate.call(
      rootFolder,
      path,
      asFolder,
      fileName,
      createdFromUnitTemplate,
    );
  }

  Widget getLeft() {
    return Builder(
      builder: (context) {
        return BuiltInFileManagerPage(
          rootPath: widget.mod.path,
          currentPath: _currentPath ?? widget.mod.path,
          onRequestOpenFile: (path) {
            Scaffold.of(context).closeDrawer();
            _onRequestOpenFile(path, true);
          },
          onCurrentPathChange: (str) {
            setState(() {
              _currentPath = str;
            });
          },
          onClickAddFile: showOperationDialogBox,
          embeddedPattern: false,
          checkBoxMode: Constant.checkBoxModeNone,
          selectedPathsChange: null,
          maxSelectCount: Constant.maxSelectCountUnlimited,
          selectFileType: FileTypeChecker.FileTypeAll,
          onRename: (String oldPath, String newPath) async {
            var isDir = await _fileSystemOperator.isDir(newPath);
            if (isDir) {
              final affectedPaths = _openedFilePath
                  .where((p) => p.startsWith(oldPath))
                  .toList();
              for (final oldSubPath in affectedPaths) {
                final newSubPath = oldSubPath.replaceFirst(oldPath, newPath);
                var fileName = await _fileSystemOperator.name(newSubPath);
                setState(() {
                  _openedFilePath.remove(oldSubPath);
                  _openedFilePath.add(newSubPath);
                  if (_unsavedFilePath.contains(oldSubPath)) {
                    _unsavedFilePath.remove(oldSubPath);
                    _unsavedFilePath.add(newSubPath);
                  }
                  final runtimeFileInfo = _pathToRuntimeFileInfo[oldPath];
                  if (runtimeFileInfo != null) {
                    runtimeFileInfo.fileName = fileName;
                    _pathToRuntimeFileInfo.remove(oldPath);
                    _pathToRuntimeFileInfo[newSubPath] = runtimeFileInfo;
                  }
                });
                saveOpenedFile();
              }
              return;
            }
            var fileName = await _fileSystemOperator.name(newPath);
            setState(() {
              _openedFilePath.remove(oldPath);
              _openedFilePath.add(newPath);
              if (_unsavedFilePath.contains(oldPath)) {
                _unsavedFilePath.remove(oldPath);
                _unsavedFilePath.add(newPath);
              }
              final runtimeFileInfo = _pathToRuntimeFileInfo[oldPath];
              if (runtimeFileInfo != null) {
                runtimeFileInfo.fileName = fileName;
                _pathToRuntimeFileInfo.remove(oldPath);
                _pathToRuntimeFileInfo[newPath] = runtimeFileInfo;
              }
            });
            saveOpenedFile();
          },
          onDelete: (String path) {
            _closeTag(path, CloseTagType.CLOSE_SELF);
          },
        );
      },
    );
  }

  void _closeTag(String path, CloseTagType type) {
    setState(() {
      if (type == CloseTagType.CLOSE_SELF) {
        // 关闭指定标签（原有逻辑，保持不变）
        int removedIndex = _openedFilePath.indexOf(path);
        _openedFilePath.remove(path);
        // 更新选中索引：如果移除的是当前选中的，选中最后一个；否则保持原索引（需处理越界）
        if (removedIndex == _targetTabIndex) {
          _targetTabIndex = _openedFilePath.isEmpty
              ? 0
              : _openedFilePath.length - 1;
        } else if (removedIndex < _targetTabIndex) {
          // 如果移除的是当前选中索引之前的标签，索引减1
          _targetTabIndex -= 1;
        }
        // 清理关联数据
        _unsavedFilePath.remove(path);
        _pathToRuntimeFileInfo.remove(path);
      } else if (type == CloseTagType.CLOSE_OTHER) {
        // 关闭除指定标签外的所有标签（原有逻辑，保持不变）
        if (!_openedFilePath.contains(path)) {
          // 指定路径不在已打开列表中，直接返回
          return;
        }
        // 收集要删除的路径
        List<String> toRemovePaths = _openedFilePath
            .where((p) => p != path)
            .toList();
        // 清理要删除的路径的关联数据
        for (String p in toRemovePaths) {
          _unsavedFilePath.remove(p);
          _pathToRuntimeFileInfo.remove(p);
        }
        // 保留指定路径，重置打开列表
        _openedFilePath.clear();
        _openedFilePath.add(path);
        // 选中唯一的标签
        _targetTabIndex = 0;
      } else if (type == CloseTagType.CLOSE_LEFT) {
        // 关闭当前标签左侧所有标签
        // 1. 校验路径是否存在，避免无效操作
        int currentIndex = _openedFilePath.indexOf(path);
        if (currentIndex <= 0) {
          // 当前标签是第一个（索引0）或路径不存在，无需操作
          return;
        }
        // 2. 收集左侧所有要删除的路径（0 ~ currentIndex-1）
        List<String> toRemovePaths = _openedFilePath.sublist(0, currentIndex);
        // 3. 批量清理关联数据
        for (String p in toRemovePaths) {
          _unsavedFilePath.remove(p);
          _pathToRuntimeFileInfo.remove(p);
        }
        // 4. 移除左侧标签，保留当前及右侧标签
        _openedFilePath.removeWhere((p) => toRemovePaths.contains(p));
        // 5. 更新选中索引：左侧标签删除后，当前标签索引变为0（原currentIndex - 移除数量 = 0）
        _targetTabIndex = 0;
      } else if (type == CloseTagType.CLOSE_RIGHT) {
        // 关闭当前标签右侧所有标签
        // 1. 校验路径是否存在，避免无效操作
        int currentIndex = _openedFilePath.indexOf(path);
        int lastIndex = _openedFilePath.length - 1;
        if (currentIndex == -1 || currentIndex >= lastIndex) {
          // 路径不存在 或 当前标签是最后一个，无需操作
          return;
        }
        // 2. 收集右侧所有要删除的路径（currentIndex+1 ~ 末尾）
        List<String> toRemovePaths = _openedFilePath.sublist(currentIndex + 1);
        // 3. 批量清理关联数据
        for (String p in toRemovePaths) {
          _unsavedFilePath.remove(p);
          _pathToRuntimeFileInfo.remove(p);
        }
        // 4. 移除右侧标签，保留当前及左侧标签
        _openedFilePath.removeWhere((p) => toRemovePaths.contains(p));
        // 5. 更新选中索引：当前标签位置未变，索引保持不变（无需修改）
        // 额外处理：如果删除后列表为空，索引置0
        if (_openedFilePath.isEmpty) {
          _targetTabIndex = 0;
        }
      } else if (type == CloseTagType.CLOSE_ALL) {
        // 关闭所有标签（原有逻辑，保持不变）
        _openedFilePath.clear();
        _unsavedFilePath.clear();
        _pathToRuntimeFileInfo.clear();
        _targetTabIndex = 0;
      }
    });
    // 保存更新后的打开文件列表
    saveOpenedFile();
  }

  /**
   * 当数据改变时，
   * file文件路径
   * newData新的数据
   * overRiderValue是否覆盖用户输入的值
   */
  void onDataChange(String? file, String? newData, bool overRiderValue) {
    if (file == null) {
      return;
    }
    setState(() {
      RuntimeFileInfo? runtimeFileInfo = _pathToRuntimeFileInfo[file];
      if (runtimeFileInfo == null) {
        return;
      }
      if (overRiderValue) {
        runtimeFileInfo.overRiderValue = true;
      } else {
        runtimeFileInfo.overRiderValue = false;
      }
      if (newData == null) {
        runtimeFileInfo.data = null;
        runtimeFileInfo.origin = null;
        _unsavedFilePath.remove(file);
        return;
      }
      if (runtimeFileInfo.data == null) {
        runtimeFileInfo.data = newData;
        runtimeFileInfo.origin = newData;
        _unsavedFilePath.remove(file);
        return;
      }
      bool same = runtimeFileInfo.origin == newData;
      runtimeFileInfo.data = newData;
      if (same) {
        if (_unsavedFilePath.contains(file)) {
          _unsavedFilePath.remove(file);
        }
      } else {
        if (!_unsavedFilePath.contains(file)) {
          _unsavedFilePath.add(file);
        }
      }
    });
  }

  Widget getRight() {
    return Builder(
      builder: (c) {
        return WorkspacePage(
          openedFileLen: _openedFilePath.length,
          globalResource: _globalResource,
          openedFilePath: _openedFilePath,
          unsavedFilePath: _unsavedFilePath,
          targetTabIndex: _targetTabIndex,
          onTabIndexChange: (index) {
            setState(() {
              _targetTabIndex = index;
            });
          },
          navigateToTheDirectory: (path) {
            setState(() {
              _currentPath = path;
            });
            Scaffold.of(c).openDrawer();
          },
          displayLineNumber: _displayLineNumber,
          displayOperationOptions: _displayOperationOptions,
          onRequestOpenDrawer: () {
            Scaffold.of(c).openDrawer();
          },
          onRequestShowCreateFileDialog: showCreateFileOrFolderDialog,
          onRequestOpenFile: (path) {
            //需要请求刷新侧边栏
            setState(() {
              _currentPath = Constant.currentPathRefresh;
            });
            _onRequestOpenFile(path, true);
          },
          pathToRuntimeFileInfo: _pathToRuntimeFileInfo,
          rootPath: widget.mod.path,
          tagList: _tagList,
          onRequestChangeLeftWidget: () {
            setState(() {
              _showLeftWidget = !_showLeftWidget;
            });
          },
          closeTag: (String p1, CloseTagType type) {
            _closeTag(p1, type);
          },
          modUnit: _projectAnalyzer.unitRefList,
          onDataChange: onDataChange,
        );
      },
    );
  }

  @override
  void onWindowBlur() {
    _performAutoSave();
  }

  @override
  void dispose() {
    _progressInfoNotifier.dispose();
    _focusNode.dispose();
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setDisplayOperationOptions(bool value) {
    setState(() {
      _displayOperationOptions = value;
    });
    HiveHelper.put(HiveHelper.displayOperationOptions, value);
  }

  void _setDisplayLineNumber(bool value) {
    setState(() {
      _displayLineNumber = value;
    });
    HiveHelper.put(HiveHelper.toggleLineNumber, value);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.editUnit),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.arrow_back_outlined),
              onPressed: () {
                Navigator.pop(context);
              },
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.globalSearch,
            icon: ValueListenableBuilder<ProgressInfo>(
              valueListenable: _progressInfoNotifier,
              builder: (context, progressInfo, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.search_outlined,
                      size: progressInfo.analysis ? 18 : 24,
                    ),
                    if (progressInfo.analysis)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          value: progressInfo.value == -1
                              ? null
                              : progressInfo.value,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            onPressed: () {
              showModalBottomSheet(
                isScrollControlled: true,
                showDragHandle: true,
                context: context,
                builder: (context) {
                  return ValueListenableBuilder<ProgressInfo>(
                    valueListenable: _progressInfoNotifier,
                    builder: (context, progressInfo, _) {
                      return AnalyticsDialog(
                        result: _projectAnalyzer.lastResult,
                        progressInfo: progressInfo,
                        onRequestOpenFile: _onRequestOpenFile,
                        onCancelAnalytics: () {
                          _cancelAnalytics = true;
                        },
                        onRescan: () {
                          _doAnalyze(context);
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.saveAction,
            onPressed: _unsavedFilePath.isEmpty ? null : _performSave,
            icon: const Icon(Icons.save_outlined),
          ),
          if (_projectAnalyzer.lastResult != null &&
              _projectAnalyzer.lastResult!.problems.isNotEmpty)
            IconButton(
              tooltip: AppLocalizations.of(context)!.problem,
              onPressed: _unsavedFilePath.isEmpty
                  ? () {
                      showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        isScrollControlled: true,
                        builder: (context) {
                          return ProblemDialog(
                            onRequestOpenFile: _onRequestOpenFile,
                            problemItemList:
                                _projectAnalyzer.lastResult!.problems,
                            onRescan: () {
                              setState(() {
                                _projectAnalyzer.lastResult!.problems.clear();
                              });
                              reloadAllOpenedFileAfterAnalyze = true;
                              _doAnalyze(context);
                            },
                          );
                        },
                      );
                    }
                  : null,
              icon: const Icon(Icons.error_outline),
            ),
          PopupMenuButton<String>(
            tooltip: AppLocalizations.of(context)!.moreActions,
            onSelected: (value) {
              if (value == 'toggle_line_number') {
                _setDisplayLineNumber(!_displayLineNumber);
              } else if (value == 'show_source_diff') {
                _showSourceDiff.call();
              } else if (value == 'display_operation_options') {
                _setDisplayOperationOptions(!_displayOperationOptions);
              } else if (value == 'saveAsTemplate') {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    final nowOpened = _openedFilePath[_targetTabIndex];
                    return SaveAsTemplateDialog(path: nowOpened);
                  },
                );
              } else if (value == 'manageCustomTemplates') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return ManagementTemplatePage();
                    },
                  ),
                );
              } else if (value == 'reloadDataFromFile') {
                final nowOpenedPath = _openedFilePath[_targetTabIndex];
                if (_unsavedFilePath.contains(nowOpenedPath)) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(
                          AppLocalizations.of(context)!.loadDataFromFile,
                        ),
                        content: Text(
                          AppLocalizations.of(context)!.notSavedYet,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                          TextButton(
                            onPressed: () {
                              onDataChange(nowOpenedPath, null, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.loadingCompleted,
                                  ),
                                ),
                              );
                              Navigator.pop(context);
                            },
                            child: Text(AppLocalizations.of(context)!.confirm),
                          ),
                        ],
                      );
                    },
                  );
                } else {
                  onDataChange(nowOpenedPath, null, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.loadingCompleted,
                      ),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) {
              int fileType = FileTypeChecker.FileTypeUnknown;
              if (_openedFilePath.isNotEmpty) {
                final nowOpened = _openedFilePath[_targetTabIndex];
                fileType = FileTypeChecker.getFileType(nowOpened);
              }
              return [
                PopupMenuItem<String>(
                  value: 'toggle_line_number',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)!.toggleLineNumber),
                      Switch(
                        value: _displayLineNumber,
                        onChanged: (b) {
                          Navigator.pop(context);
                          _setDisplayLineNumber(b);
                        },
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'display_operation_options',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.displayOperationOptions,
                      ),
                      Switch(
                        value: _displayOperationOptions,
                        onChanged: (b) {
                          Navigator.pop(context);
                          _setDisplayOperationOptions(b);
                        },
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'manageCustomTemplates',
                  child: Text(
                    AppLocalizations.of(context)!.manageCustomTemplates,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'show_source_diff',
                  enabled:
                      _openedFilePath.isNotEmpty &&
                      fileType == FileTypeChecker.FileTypeText,
                  child: Text(AppLocalizations.of(context)!.showSourceDiff),
                ),
                PopupMenuItem<String>(
                  value: 'saveAsTemplate',
                  enabled:
                      _openedFilePath.isNotEmpty &&
                      fileType == FileTypeChecker.FileTypeText,
                  child: Text(AppLocalizations.of(context)!.saveAsTemplate),
                ),
                PopupMenuItem<String>(
                  value: 'reloadDataFromFile',
                  enabled:
                      _openedFilePath.isNotEmpty &&
                      fileType == FileTypeChecker.FileTypeText,
                  child: Text(AppLocalizations.of(context)!.loadDataFromFile),
                ),
              ];
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      drawer: screenWidth > 600 ? null : Drawer(child: getLeft()),
      body: screenWidth > 600
          ? Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (_showLeftWidget)
                        SizedBox(width: 300, child: getLeft()),
                      Expanded(child: getRight()),
                    ],
                  ),
                ),
                ValueListenableBuilder<ProgressInfo>(
                  valueListenable: _progressInfoNotifier,
                  child: Padding(padding: EdgeInsetsGeometry.all(8)),
                  builder: (context, progressInfo, _) {
                    if (progressInfo.message == null) {
                      return SizedBox();
                    }
                    return Align(
                      alignment: AlignmentGeometry.centerRight,
                      child: Text(
                        progressInfo.message!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ],
            )
          : Column(
              children: [
                Expanded(child: getRight()),
                ValueListenableBuilder<ProgressInfo>(
                  valueListenable: _progressInfoNotifier,
                  child: Padding(padding: EdgeInsetsGeometry.all(8)),
                  builder: (context, progressInfo, _) {
                    if (progressInfo.message == null) {
                      return SizedBox();
                    }
                    return Align(
                      alignment: AlignmentGeometry.centerRight,
                      child: Text(
                        progressInfo.message!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
