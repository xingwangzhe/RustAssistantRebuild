import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:rust_assistant/file_operator/file_operator.dart';
import 'package:rust_assistant/global_depend.dart';
import 'package:rust_assistant/l10n/app_localizations.dart';
import 'package:rust_assistant/mod/line_parser.dart';

import '../databeans/visual_analytics_result.dart';

class ProblemDialog extends StatefulWidget {
  final List<ProblemItem> problemItemList;
  final Function(String, bool) onRequestOpenFile;
  final Function onRescan;

  const ProblemDialog({
    super.key,
    required this.problemItemList,
    required this.onRequestOpenFile,
    required this.onRescan,
  });

  @override
  State<StatefulWidget> createState() {
    return _ProblemDialogStatus();
  }
}

class _ProblemDialogStatus extends State<ProblemDialog> {
  bool pressing = false;

  void _pressedAll(BuildContext buildContext) async {
    setState(() {
      pressing = true;
    });
    Set<String> problemSet = {};
    for (ProblemItem problemItem in widget.problemItemList) {
      String? path = problemItem.path;
      if (path == null) {
        continue;
      }
      problemSet.add(path);
    }
    FileSystemOperator fileSystemOperator =
        GlobalDepend.getFileSystemOperator();
    for (String p in problemSet) {
      String? content = await fileSystemOperator.readAsString(p);
      if (content == null) {
        continue;
      }
      //执行处理。
      LineParser lineParser = LineParser(content);
      Set<String> repeatKeys = {};
      StringBuffer stringBuffer = StringBuffer();
      while (true) {
        String? line = lineParser.nextLine();
        if (line == null) {
          break;
        }
        if (line.startsWith("[") && line.endsWith("]")) {
          repeatKeys.clear();
          if (stringBuffer.length > 0) {
            stringBuffer.write('\n');
          }
          stringBuffer.write(line);
          continue;
        }
        var symbol = line.indexOf(':');
        if (symbol > -1) {
          var keyName = line.substring(0, symbol);
          if (repeatKeys.contains(keyName)) {
            //A duplicate key has been found.
            //发现重复key。
            continue;
          }
          if (stringBuffer.length > 0) {
            stringBuffer.write('\n');
          }
          stringBuffer.write(line);
          repeatKeys.add(keyName);
        } else {
          if (stringBuffer.length > 0) {
            stringBuffer.write('\n');
          }
          stringBuffer.write(line);
        }
      }
      String folderPath = path.dirname(p);
      String fileName = path.basename(p);
      fileSystemOperator.writeFile(
        folderPath,
        fileName,
        stringBuffer.toString(),
      );
    }
    widget.onRescan.call();
    //关闭对话框
    if (buildContext.mounted) {
      ScaffoldMessenger.of(buildContext).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(buildContext)!.problemResolved),
        ),
      );
      Navigator.pop(buildContext, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.problem,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton(
                onPressed: pressing
                    ? null
                    : () {
                        _pressedAll(context);
                      },
                child: Text(AppLocalizations.of(context)!.handleAll),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.problemItemList.length,
              itemBuilder: (context, index) {
                final problem = widget.problemItemList[index];
                return ListTile(
                  title: Text(AppLocalizations.of(context)!.redefinition),
                  subtitle: problem.message == null
                      ? null
                      : Text(problem.message!),
                  onTap: () {
                    final path = problem.path;
                    if (path != null) {
                      widget.onRequestOpenFile.call(path, true);
                    }
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
