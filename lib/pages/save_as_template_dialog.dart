import 'package:flutter/material.dart';
import 'package:rust_assistant/code_data_base.dart';
import 'package:rust_assistant/file_operator/file_operator.dart';
import 'package:rust_assistant/l10n/app_localizations.dart';
import 'package:sprintf/sprintf.dart';

import '../global_depend.dart';

class SaveAsTemplateDialog extends StatefulWidget {
  final String path;

  const SaveAsTemplateDialog({super.key, required this.path});

  @override
  State<StatefulWidget> createState() {
    return _SaveAsTemplateStatus();
  }
}

class _SaveAsTemplateStatus extends State<SaveAsTemplateDialog> {
  final TextEditingController _textEditingController = TextEditingController();
  String? _errorText;
  String _fileName = '';
  String _templatePath = '';

  @override
  void initState() {
    super.initState();
    initName();
    _templatePath = HiveHelper.get(HiveHelper.templatePath);
    _textEditingController.addListener(() async {
      FileSystemOperator fileSystemOperator =
          GlobalDepend.getFileSystemOperator();
      String path = fileSystemOperator.join(
        _templatePath,
        _textEditingController.text,
      );
      if (_textEditingController.text.isEmpty) {
        setState(() {
          _errorText = AppLocalizations.of(context)!.titleCannotBeEmpty;
        });
      } else {
        if (await fileSystemOperator.exist(path)) {
          setState(() {
            _errorText = sprintf(
              AppLocalizations.of(context)!.fileRepeatedlyPrompts,
              [_textEditingController.text],
            );
          });
        } else {
          setState(() {
            _errorText = null;
          });
        }
      }
      setState(() {
        _fileName = _textEditingController.text;
      });
    });
  }

  void initName() async {
    String name = await GlobalDepend.getFileSystemOperator().name(widget.path);
    setState(() {
      _fileName = name;
    });
    _textEditingController.text = _fileName;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.saveAsTemplate),
      content: TextField(
        controller: _textEditingController,
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          label: Text(AppLocalizations.of(context)!.fileName),
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, false);
          },
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        TextButton(
          onPressed: _fileName.isEmpty || _errorText != null
              ? null
              : () async {
                  FileSystemOperator fileSystemOperator =
                      GlobalDepend.getFileSystemOperator();
                  String? content = await fileSystemOperator.readAsString(
                    widget.path,
                  );
                  bool success = false;
                  if (content != null) {
                    await GlobalDepend.getFileSystemOperator().writeFile(
                      _templatePath,
                      _fileName,
                      content,
                    );
                    CodeDataBase.loadCustomTemplate();
                    success = true;
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? AppLocalizations.of(
                                  context,
                                )!.templateSavedSuccessfully
                              : AppLocalizations.of(
                                  context,
                                )!.templateSavedFailed,
                        ),
                      ),
                    );
                    Navigator.pop(context, true);
                  }
                },
          child: Text(AppLocalizations.of(context)!.save),
        ),
      ],
    );
  }
}
