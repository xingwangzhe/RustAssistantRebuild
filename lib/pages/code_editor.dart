import 'package:flutter/material.dart';
import 'package:rust_assistant/l10n/app_localizations.dart';

class CodeEditor extends StatefulWidget {
  final String? text;
  final void Function(String)? onSubmit;

  const CodeEditor({super.key, required this.text, required this.onSubmit});

  @override
  State<StatefulWidget> createState() {
    return _CodeEditorStatus();
  }
}

class _CodeEditorStatus extends State<CodeEditor> {
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.text != null) {
      _textEditingController.text = widget.text!;
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.editor,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsetsGeometry.fromLTRB(16, 8, 16, 0),
              child: TextField(
                style: TextStyle(fontFamily: 'Mono'),
                textAlignVertical: TextAlignVertical.top,
                expands: true,
                maxLines: null,
                controller: _textEditingController,
                decoration: InputDecoration(border: OutlineInputBorder()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () {
                  widget.onSubmit?.call(_textEditingController.text);
                  Navigator.of(context).pop();
                },
                child: Text(AppLocalizations.of(context)!.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
