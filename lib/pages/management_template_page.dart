import 'package:flutter/material.dart';
import 'package:rust_assistant/code_data_base.dart';
import 'package:rust_assistant/delete_file_dialog.dart';
import 'package:rust_assistant/l10n/app_localizations.dart';

import '../databeans/unit_template.dart';

class ManagementTemplatePage extends StatefulWidget {
  const ManagementTemplatePage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ManagementTemplatePageStatus();
  }
}

class _ManagementTemplatePageStatus extends State<ManagementTemplatePage> {
  List<Templates> customTemplates = List.empty(growable: true);

  @override
  void initState() {
    super.initState();
    customTemplates = CodeDataBase.getCustomTemplate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.manageCustomTemplates),
      ),
      body: _buildTemplateList(),
    );
  }

  Widget _buildTemplateList() {
    // 空列表状态处理
    if (customTemplates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.file_copy_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noCustomTemplates,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      itemCount: customTemplates.length,
      itemBuilder: (context, index) {
        final template = customTemplates[index];
        return Card.filled(
          child: ListTile(
            title: Text(
              template.name!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            leading: const Icon(Icons.insert_drive_file_outlined),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () => _deleteTemplate(index),
              tooltip: AppLocalizations.of(context)?.delete,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  void _deleteTemplate(int index) async {
    Templates templates = customTemplates[index];
    bool result = await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return DeleteFileDialog(path: templates.path!, name: templates.name!);
      },
    );
    if (result) {
      setState(() {
        customTemplates.removeAt(index);
      });
      CodeDataBase.loadCustomTemplate();
    }
  }
}
