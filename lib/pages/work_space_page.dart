import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:rust_assistant/databeans/resource_ref.dart';
import 'package:rust_assistant/databeans/runtime_file_info.dart';
import 'package:rust_assistant/databeans/unit_ref.dart';
import 'package:rust_assistant/file_operator/file_operator.dart';
import 'package:rust_assistant/file_type_checker.dart';
import 'package:rust_assistant/pages/image_viewer.dart';
import 'package:rust_assistant/scrollable_tabBar_with_mouse_wheel.dart';
import 'package:url_launcher/url_launcher.dart';

import '../global_depend.dart';
import '../l10n/app_localizations.dart';

import '../open_file_parameters.dart';
import 'edit_units_page.dart';
import 'ini_editor_page.dart';

class WorkspacePage extends StatefulWidget {
  final List<OpenFileParameters> openedFilePath;
  final int openedFileLen;
  final int targetTabIndex;
  final List<String> unsavedFilePath;
  final Map<String, RuntimeFileInfo> pathToRuntimeFileInfo;
  final List<String> tagList;
  final List<ResourceRef> globalResource;
  final Function(int) onTabIndexChange;
  final Function(String)? navigateToTheDirectory;
  final Function(String?, String?, bool) onDataChange;
  final Function(OpenFileParameters, CloseTagType)? closeTag;
  final bool displayLineNumber;
  final bool displayOperationOptions;
  final Function onRequestOpenDrawer;
  final Function onRequestChangeLeftWidget;
  final Function(OpenFileParameters) onRequestOpenFile;
  final Function(
    Function(String, String, bool, String, bool) onCreate, {
    String? folder,
  })
  onRequestShowCreateFileDialog;
  final String rootPath;
  final List<UnitRef> modUnit;

  const WorkspacePage({
    super.key,
    required this.rootPath,
    required this.openedFileLen,
    required this.globalResource,
    required this.openedFilePath,
    required this.unsavedFilePath,
    required this.targetTabIndex,
    required this.onTabIndexChange,
    required this.navigateToTheDirectory,
    required this.displayLineNumber,
    required this.onRequestOpenDrawer,
    required this.onRequestShowCreateFileDialog,
    required this.displayOperationOptions,
    required this.onRequestOpenFile,
    required this.pathToRuntimeFileInfo,
    required this.onDataChange,
    required this.modUnit,
    required this.tagList,
    required this.onRequestChangeLeftWidget,
    required this.closeTag,
  });

  @override
  State<StatefulWidget> createState() {
    return _WorkspaceStatus();
  }
}

class _WorkspaceStatus extends State<WorkspacePage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final FileSystemOperator _fileSystemOperator =
      GlobalDepend.getFileSystemOperator();

  @override
  void initState() {
    super.initState();
    if (widget.openedFileLen > 0) {
      //确保状态被销毁后，有文件处于打开状态，那么重建TabController。例如，从大屏幕切换到小屏幕，会销毁对象。那么我们在这里创建_tabController。
      _tabController = TabController(length: widget.openedFileLen, vsync: this);
      addListener();
    }
  }

  List<Widget> getTabs() {
    List<Widget> widgets = List.empty(growable: true);
    if (widget.openedFilePath.isNotEmpty) {
      for (var f in widget.openedFilePath) {
        List<MenuItemButton> menuItemButtonList = List.empty(growable: true);
        menuItemButtonList.add(
          MenuItemButton(
            requestFocusOnHover: false,
            onPressed: () async {
              widget.navigateToTheDirectory?.call(
                await _fileSystemOperator.dirname(f.path),
              );
            },
            child: Text(
              AppLocalizations.of(
                context,
              )!.navigateToTheDirectoryWhereTheFileIsLocated,
            ),
          ),
        );
        if (Platform.isWindows || Platform.isLinux) {
          menuItemButtonList.add(
            MenuItemButton(
              requestFocusOnHover: false,
              onPressed: () async {
                var uri = Uri.parse("file:${path.dirname(f.path)}");
                var finalContext = context;
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  if (finalContext.mounted) {
                    ScaffoldMessenger.of(finalContext).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(finalContext)!.fail),
                      ),
                    );
                  }
                }
              },
              child: Text(AppLocalizations.of(context)!.openItInTheFileManager),
            ),
          );
        }

        menuItemButtonList.add(
          MenuItemButton(
            requestFocusOnHover: false,
            onPressed: () async {
              widget.closeTag?.call(f, CloseTagType.CLOSE_SELF);
            },
            child: Text(AppLocalizations.of(context)!.close),
          ),
        );

        menuItemButtonList.add(
          MenuItemButton(
            requestFocusOnHover: false,
            onPressed: () async {
              widget.closeTag?.call(f, CloseTagType.CLOSE_OTHER);
            },
            child: Text(AppLocalizations.of(context)!.closeOtherTabs),
          ),
        );
        menuItemButtonList.add(
          MenuItemButton(
            requestFocusOnHover: false,
            onPressed: () async {
              widget.closeTag?.call(f, CloseTagType.CLOSE_ALL);
            },
            child: Text(AppLocalizations.of(context)!.closeAllTabs),
          ),
        );
        menuItemButtonList.add(
          MenuItemButton(
            requestFocusOnHover: false,
            onPressed: () async {
              widget.closeTag?.call(f, CloseTagType.CLOSE_LEFT);
            },
            child: Text(AppLocalizations.of(context)!.closeLeftHandTab),
          ),
        );
        menuItemButtonList.add(
          MenuItemButton(
            requestFocusOnHover: false,
            onPressed: () async {
              widget.closeTag?.call(f, CloseTagType.CLOSE_RIGHT);
            },
            child: Text(AppLocalizations.of(context)!.closeRightHandTab),
          ),
        );

        var contains = widget.unsavedFilePath.contains(f.path);
        var runtimeFile = widget.pathToRuntimeFileInfo[f.path];
        var tab = Tab(
          child: Row(
            children: [
              Text(runtimeFile?.fileName ?? f.path),
              MenuAnchor(
                builder: (context, controller, child) {
                  return IconButton(
                    onPressed: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    icon: Icon(Icons.more_vert_outlined),
                  );
                },
                menuChildren: menuItemButtonList,
              ),
            ],
          ),
        );
        widgets.add(contains ? Badge(child: tab) : tab);
      }
    }
    return widgets;
  }

  List<Widget> getViews() {
    List<Widget> widgets = List.empty(growable: true);
    if (widget.openedFilePath.isNotEmpty) {
      for (var f in widget.openedFilePath) {
        var fileType =
            widget.pathToRuntimeFileInfo[f.path]?.fileType ??
            FileTypeChecker.FileTypeUnknown;
        if (fileType == FileTypeChecker.FileTypeImage) {
          widgets.add(ImageViewer(path: f.path));
          continue;
        }
        if (fileType == FileTypeChecker.FileTypeText) {
          widgets.add(
            IniEditorPage(
              key: PageStorageKey<String>(f.path),
              sourceFilePath: f.path,
              readOnly: f.readOnly,
              globalResource: widget.globalResource,
              fileData: widget.pathToRuntimeFileInfo[f.path]?.data,
              overRiderValue:
                  widget.pathToRuntimeFileInfo[f.path]?.overRiderValue ?? false,
              onDataChange: (data, overRide) {
                widget.onDataChange.call(f.path, data, overRide);
              },
              displayLineNumber: widget.displayLineNumber,
              onMaxLineNumberChange: (lineNumber) {
                if (widget.pathToRuntimeFileInfo[f.path] == null) {
                  return;
                }
                widget.pathToRuntimeFileInfo[f.path]?.maxLineNumber =
                    lineNumber;
              },
              onRequestOpenDrawer: widget.onRequestOpenDrawer,
              onRequestChangeLeftWidget: widget.onRequestChangeLeftWidget,
              displayOperationOptions: widget.displayOperationOptions,
              onRequestOpenFile: widget.onRequestOpenFile,
              modPath: widget.rootPath,
              tagList: widget.tagList,
              modUnit: widget.modUnit,
            ),
          );
          continue;
        }
        widgets.add(
          Center(
            child: Text(AppLocalizations.of(context)!.fileNotSupportedOpening),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  void didUpdateWidget(covariant WorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openedFileLen != widget.openedFileLen) {
      _tabController?.dispose();
      _tabController = TabController(length: widget.openedFileLen, vsync: this);
      addListener();
    }
    if (widget.openedFileLen > 0) {
      _tabController?.animateTo(widget.targetTabIndex);
    }
  }

  void addListener() {
    var finalTabController = _tabController;
    if (finalTabController == null) {
      return;
    }
    finalTabController.addListener(() {
      widget.onTabIndexChange(finalTabController.index);
    });
  }

  void onCreate(
    String folder,
    String path,
    bool asFolder,
    String fileName,
    bool writeTheNecessaryCode,
  ) {
    if (asFolder) {
      widget.onRequestOpenDrawer.call();
    } else {
      widget.onRequestOpenFile.call(
        OpenFileParameters(path: path, readOnly: false),
      );
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (widget.openedFileLen == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 添加图标
            Icon(
              Icons.folder_open,
              size: 48,
              color: Theme.of(context).iconTheme.color,
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.startQuickly,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => {
                widget.onRequestShowCreateFileDialog.call(onCreate),
              },
              child: Text(AppLocalizations.of(context)!.createNewFile),
            ),
            if (screenWidth < 600) SizedBox(height: 8),
            if (screenWidth < 600)
              TextButton(
                onPressed: () => {widget.onRequestOpenDrawer.call()},
                child: Text(AppLocalizations.of(context)!.openAnExistingFile),
              ),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: widget.openedFileLen,
      child: Scaffold(
        appBar: Platform.isWindows || Platform.isLinux
            ? PreferredSize(
                preferredSize: Size.fromHeight(48),
                child: ScrollableTabBarWithMouseWheel(
                  tabBar: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: getTabs(),
                  ),
                ),
              )
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: getTabs(),
              ),
        body: TabBarView(controller: _tabController, children: getViews()),
      ),
    );
  }
}
