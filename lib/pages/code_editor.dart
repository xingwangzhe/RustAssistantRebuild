import 'package:flutter/material.dart';
import 'package:rust_assistant/l10n/app_localizations.dart';

class CodeEditor extends StatefulWidget {
  final String? text;
  final void Function(String)? onChanged;
  final void Function(bool, String)? onNeedSyncChanged;

  const CodeEditor({
    super.key,
    required this.text,
    required this.onChanged,
    required this.onNeedSyncChanged,
  });

  @override
  State<StatefulWidget> createState() {
    return _CodeEditorStatus();
  }
}

class _CodeEditorStatus extends State<CodeEditor> {
  final TextEditingController _textEditingController = TextEditingController();
  String _original = "";
  bool _needSync = false;

  @override
  void initState() {
    super.initState();
    if (widget.text != null) {
      _textEditingController.text = widget.text!;
      _original = _textEditingController.text;
    }
    _textEditingController.addListener(() {
      setState(() {
        setNeedSyncStatus(_textEditingController.text != _original);
      });
    });
  }

  void setNeedSyncStatus(bool needSync) {
    _needSync = needSync;
    void Function(bool, String)? onNeedSyncChanged = widget.onNeedSyncChanged;
    if (onNeedSyncChanged != null) {
      onNeedSyncChanged.call(needSync, _textEditingController.text);
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    String? newText = widget.text;
    if (newText == null) {
      return;
    }
    String editorText = _textEditingController.text;
    if (newText != editorText) {
      _textEditingController.text = newText;
      _original = newText;
      setNeedSyncStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 8),
        Expanded(
          child: TextField(
            style: TextStyle(fontFamily: 'Mono'),
            textAlignVertical: TextAlignVertical.top,
            expands: true,
            maxLines: null,
            controller: _textEditingController,
            decoration: InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        Padding(
          padding: EdgeInsetsGeometry.all(8),
          child: FilledButton(
            onPressed: _needSync
                ? () {
                    final void Function(String)? onChange = widget.onChanged;
                    final String newText = _textEditingController.text
                        .toString();
                    if (onChange != null) {
                      onChange.call(newText);
                    }
                    setState(() {
                      _original = newText;
                      setNeedSyncStatus(false);
                    });
                  }
                : null,
            child: Text(AppLocalizations.of(context)!.synchronizeVisualEditor),
          ),
        ),
      ],
    );
  }
}
