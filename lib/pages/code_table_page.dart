import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rust_assistant/code_data_base.dart';
import 'package:rust_assistant/highlight_link_text.dart';
import 'package:rust_assistant/l10n/app_localizations.dart';
import 'package:sprintf/sprintf.dart';

import '../code_detail_dialog.dart';
import '../dataSources/display_code.dart';
import '../databeans/code.dart';
import '../databeans/code_info.dart';
import '../databeans/game_version.dart';
import '../databeans/section_info.dart';
import '../highlight_text.dart';

class CodeTablePage extends StatefulWidget {
  const CodeTablePage({super.key});

  @override
  State<StatefulWidget> createState() {
    return CodeTableStatus();
  }
}

class SearchData {
  late List<Code> codeList;
  late List<CodeInfo> codeInfoList;
  late List<SectionInfo> sectionInfoList;
  late String? keyWord;
  late int targetVersion;
  late Map<String, SectionInfo> sectionMaps;
}

class CodeTableStatus extends State<CodeTablePage> {
  bool _loading = true;
  Map<SectionInfo, List<DisplayCode>> sectionToDisplayCode = {};
  Timer? _debounceTimer;
  final TextEditingController _textEditingController = TextEditingController();
  String? gameVersionStr;

  @override
  void initState() {
    super.initState();

    List<GameVersion> list = CodeDataBase.getGameVersion()
        .where(
          (gv) =>
              gv.visible == true &&
              gv.versionCode == CodeDataBase.geTargetVersion(),
        )
        .toList();
    if (list.isNotEmpty) {
      gameVersionStr = list[0].versionName;
    }
    Future.delayed(Duration(milliseconds: 350), () {
      _loadData();
    });
  }

  static Future<Map<SectionInfo, List<DisplayCode>>> _processDataInIsolate(
    SearchData searchData,
  ) async {
    Map<SectionInfo, List<DisplayCode>> resultData = {};
    String? keyWord = searchData.keyWord?.toLowerCase();
    List<DisplayCode> displayCodeList = List.empty(growable: true);
    Map<String, CodeInfo> codeToInfo = {};
    for (CodeInfo codeInfo in searchData.codeInfoList) {
      String? code = codeInfo.code;
      if (code == null) {
        continue;
      }
      codeToInfo[code] = codeInfo;
    }
    for (Code code in searchData.codeList) {
      var minVersion = code.minVersion ?? 1;
      if (minVersion > searchData.targetVersion) {
        continue;
      }
      var codeRule = code.code;
      var sectionRule = code.section;
      if (codeRule == null || sectionRule == null) {
        continue;
      }
      bool match = false;
      if (keyWord == null) {
        match = true;
      } else {
        var defaultKey = code.defaultKey?.toLowerCase();
        if (defaultKey != null && defaultKey.contains(keyWord)) {
          match = true;
        }
      }
      CodeInfo? codeInfo = codeToInfo[code.code];
      if (!match && keyWord != null && codeInfo != null) {
        var translate = codeInfo.translate?.toLowerCase();
        if (translate != null && translate.contains(keyWord)) {
          match = true;
        }
      }

      if (match) {
        DisplayCode displayCode = DisplayCode();
        displayCode.code = code;
        displayCode.codeInfo = codeInfo;
        displayCodeList.add(displayCode);
      }
    }
    Map<String, SectionInfo> sectionMaps = searchData.sectionMaps;
    for (DisplayCode displayCode in displayCodeList) {
      String? section = displayCode.code?.section;
      if (section == null) {
        continue;
      }
      SectionInfo? sectionInfo = sectionMaps[section];
      if (sectionInfo == null) {
        continue;
      }
      List<DisplayCode>? displayCodeData = resultData[sectionInfo];
      if (displayCodeData == null) {
        displayCodeData = List.empty(growable: true);
        resultData[sectionInfo] = displayCodeData;
      }
      displayCodeData.add(displayCode);
    }
    return resultData;
  }

  void _loadData() async {
    setState(() {
      _loading = true;
    });
    SearchData searchData = SearchData();
    searchData.targetVersion = CodeDataBase.geTargetVersion();
    searchData.keyWord = _textEditingController.text.trim().isEmpty
        ? null
        : _textEditingController.text.trim();
    searchData.codeList = CodeDataBase.getAllCode();
    searchData.sectionInfoList = CodeDataBase.getSectionInfoList();
    searchData.codeInfoList = CodeDataBase.getAllCodeInfo();
    searchData.sectionMaps = CodeDataBase.getSectionInfoMap();
    Map<SectionInfo, List<DisplayCode>> result = await compute(
      _processDataInIsolate,
      searchData,
    );
    setState(() {
      sectionToDisplayCode = result;
      _loading = false;
    });
  }

  @override
  void dispose() {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
      _debounceTimer = null;
    }
    _textEditingController.dispose();
    super.dispose();
  }

  String getSectionTile(SectionInfo sectionInfo) {
    StringBuffer stringBuffer = StringBuffer();
    if (sectionInfo.translate != null) {
      stringBuffer.write(sectionInfo.translate);
    }
    if (sectionInfo.section != null) {
      stringBuffer.write('(');
      stringBuffer.write(sectionInfo.section);
      stringBuffer.write(')');
    }
    if (stringBuffer.length == 0) {
      stringBuffer.write(AppLocalizations.of(context)!.unknow);
    }
    return stringBuffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          gameVersionStr == null
              ? loc.codeTable
              : gameVersionStr! + loc.codeTable,
        ),
      ),
      body: Padding(
        padding: EdgeInsetsGeometry.fromLTRB(16, 8, 16, 0),
        child: Column(
          children: [
            getSearchBar(),
            Expanded(child: _buildBody(loc)),
          ],
        ),
      ),
    );
  }

  Widget getSearchBar() {
    return TextField(
      controller: _textEditingController,
      onChanged: (text) {
        if (_debounceTimer != null && _debounceTimer!.isActive) {
          _debounceTimer!.cancel();
        }
        _debounceTimer = Timer(const Duration(milliseconds: 350), () {
          if (mounted) {
            _loadData();
          }
        });
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.searchCodeOrTranslate,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(Icons.search),
      ),
    );
  }

  Widget _buildBody(AppLocalizations loc) {
    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }
    if (sectionToDisplayCode.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code_off_rounded),
            const SizedBox(height: 16),
            Text("No code found"),
            const SizedBox(height: 8),
            Text("Try changing your search keyword"),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: ExpansionPanelList.radio(
        elevation: 0,
        children: sectionToDisplayCode.entries.map((entry) {
          final section = entry.key;
          final codeList = entry.value;
          return ExpansionPanelRadio(
            value: section,
            headerBuilder: (context, isExpanded) {
              return ListTile(
                title: Text(getSectionTile(section)),
                subtitle: Text(sprintf(loc.itemNumber, [codeList.length])),
              );
            },
            body: ListView.builder(
              shrinkWrap: true,
              itemCount: codeList.length,
              itemBuilder: (context, index) {
                final displayCode = codeList[index];
                return _buildCodeItem(displayCode, loc);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCodeItem(DisplayCode displayCode, AppLocalizations loc) {
    String unknow = loc.unknow;
    final code = displayCode.code;
    final codeInfo = displayCode.codeInfo;
    final translate = codeInfo?.translate ?? unknow;
    final description = codeInfo?.description ?? unknow;
    final defaultKey = code?.defaultKey ?? unknow;

    return Card.filled(
      child: Padding(
        padding: EdgeInsetsGeometry.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HighlightText(
              text: defaultKey,
              searchKeyword: _textEditingController.text,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            HighlightText(
              text: translate,
              searchKeyword: _textEditingController.text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            // 描述
            HighlightLinkText(
              text: description,
              searchKeyword: _textEditingController.text,
              style: Theme.of(context).textTheme.bodySmall,
              onSeeTap: (String code, String section) {
                showDialog(
                  context: context,
                  builder: (_) => CodeDetailDialog(
                    code: code,
                    section: section,
                    searchKeyword: "",
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
