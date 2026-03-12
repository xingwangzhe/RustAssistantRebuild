import 'package:flutter/material.dart';
import 'package:rust_assistant/l10n/app_localizations.dart';

import '../databeans/visual_analytics_result.dart';

class ProblemDialog extends StatefulWidget {
  final List<ProblemItem> problemItemList;
  final Function(String, bool) onRequestOpenFile;

  const ProblemDialog({
    super.key,
    required this.problemItemList,
    required this.onRequestOpenFile,
  });

  @override
  State<StatefulWidget> createState() {
    return _ProblemDialogStatus();
  }
}

class _ProblemDialogStatus extends State<ProblemDialog> {
  List<ProblemItem> problemItemList = List.empty(growable: true);

  @override
  void initState() {
    super.initState();
    problemItemList = widget.problemItemList;
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
                onPressed: null,
                child: Text(AppLocalizations.of(context)!.handleAll),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: problemItemList.length,
              itemBuilder: (context, index) {
                final problem = problemItemList[index];
                return ListTile(
                  title: Text(AppLocalizations.of(context)!.redefinition),
                  subtitle: Text(problem.message ?? ""),
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
