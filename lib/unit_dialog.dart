import 'package:flutter/material.dart';
import 'package:rust_assistant/code_data_base.dart';
import 'package:rust_assistant/databeans/unit_ref.dart';
import 'package:rust_assistant/highlight_text.dart';
import 'package:rust_assistant/l10n/app_localizations.dart';

class UnitDialog extends StatefulWidget {
  final List<UnitRef> modUnit;
  final String value;
  final bool multiple;
  final Function(List<UnitRef>) onSave;
  final bool displayOnlyBuiltinUnits;

  const UnitDialog({
    super.key,
    required this.modUnit,
    required this.displayOnlyBuiltinUnits,
    required this.value,
    required this.multiple,
    required this.onSave,
  });

  @override
  State<StatefulWidget> createState() {
    return _UnitDialogStatus();
  }
}

class _UnitDialogStatus extends State<UnitDialog> {
  final TextEditingController _searchController = TextEditingController();
  final List<UnitRef> _allUnit = List.empty(growable: true);
  final List<UnitRef> _filteredUnit = List.empty(growable: true);
  final Set<String> _unitList = {};
  final Map<String, UnitRef> nameToUnitRef = {};

  @override
  void dispose() {
    super.dispose();
    _searchController.dispose();
  }

  @override
  void initState() {
    super.initState();
    //添加内置单位
    _allUnit.clear();

    for (var value in CodeDataBase.builtInUnit) {
      String? name = value.name;
      if (name != null) {
        nameToUnitRef[name] = value;
      }
      if (widget.displayOnlyBuiltinUnits) {
        if (value.type == UnitRefType.BUILT_IN) {
          _allUnit.add(value);
        }
      } else {
        _allUnit.add(value);
      }
    }

    if (!widget.displayOnlyBuiltinUnits) {
      for (var value in widget.modUnit) {
        String? name = value.name;
        if (name != null) {
          nameToUnitRef[name] = value;
        }
        _allUnit.add(value);
      }
    }
    _allUnit.sort((a, b) {
      final aName = a.name?.toLowerCase() ?? "";
      final bName = b.name?.toLowerCase() ?? "";
      return aName.compareTo(bName);
    });
    _filteredUnit.addAll(_allUnit);
    var unitList = widget.value.split(',');
    for (String unitName in unitList) {
      var unitNameTrim = unitName.trim();
      if (unitNameTrim.isNotEmpty && !_unitList.contains(unitNameTrim)) {
        _unitList.add(unitNameTrim);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  widget.displayOnlyBuiltinUnits
                      ? AppLocalizations.of(context)!.originalUnit
                      : AppLocalizations.of(context)!.unitSelector,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                var lowerCaseValue = value.toLowerCase();
                List<UnitRef> newData = List.empty(growable: true);
                for (UnitRef unitRef in _allUnit) {
                  var name = unitRef.name;
                  if (name == null) {
                    continue;
                  }
                  bool match = false;
                  if (name.toLowerCase().contains(lowerCaseValue)) {
                    match = true;
                  }
                  if (!match) {
                    var displayName = unitRef.displayName;
                    if (displayName == null) {
                      continue;
                    }
                    if (displayName.toLowerCase().contains(lowerCaseValue)) {
                      match = true;
                    }
                  }
                  if (match) {
                    newData.add(unitRef);
                  }
                }
                setState(() {
                  _filteredUnit.clear();
                  _filteredUnit.addAll(newData);
                });
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                hintText: AppLocalizations.of(
                  context,
                )!.searchByTitleAndDescription,
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredUnit.length,
                itemBuilder: (context, index) {
                  var unitData = _filteredUnit[index];
                  if (widget.multiple) {
                    return CheckboxListTile(
                      title: unitData.type != UnitRefType.MOD
                          ? Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                Chip(
                                  label: Text(
                                    unitData.type == UnitRefType.BUILT_IN
                                        ? AppLocalizations.of(context)!.builtIn
                                        : AppLocalizations.of(
                                            context,
                                          )!.dexBuiltIn,
                                  ),
                                ),
                                HighlightText(
                                  text:
                                      unitData.name ??
                                      AppLocalizations.of(context)!.none,
                                  searchKeyword: _searchController.text,
                                ),
                              ],
                            )
                          : HighlightText(
                              text:
                                  unitData.name ??
                                  AppLocalizations.of(context)!.none,
                              searchKeyword: _searchController.text,
                            ),
                      subtitle: unitData.displayName == null
                          ? null
                          : HighlightText(
                              text: unitData.displayName!,
                              searchKeyword: _searchController.text,
                            ),
                      value: unitData.name == null
                          ? false
                          : _unitList.contains(unitData.name),
                      onChanged: (newValue) {
                        if (newValue == null) {
                          return;
                        }
                        setState(() {
                          if (newValue) {
                            _unitList.add(unitData.name!);
                          } else {
                            _unitList.remove(unitData.name!);
                          }
                        });
                      },
                    );
                  }
                  // 单选模式
                  return RadioListTile<String>(
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: unitData.type != UnitRefType.MOD
                        ? Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  unitData.type == UnitRefType.BUILT_IN
                                      ? AppLocalizations.of(context)!.builtIn
                                      : AppLocalizations.of(
                                          context,
                                        )!.dexBuiltIn,
                                ),
                              ),
                              HighlightText(
                                text:
                                    unitData.name ??
                                    AppLocalizations.of(context)!.none,
                                searchKeyword: _searchController.text,
                              ),
                            ],
                          )
                        : HighlightText(
                            text:
                                unitData.name ??
                                AppLocalizations.of(context)!.none,
                            searchKeyword: _searchController.text,
                          ),
                    subtitle: unitData.displayName == null
                        ? null
                        : HighlightText(
                            text: unitData.displayName!,
                            searchKeyword: _searchController.text,
                          ),
                    value: unitData.name ?? "",
                    groupValue: _unitList.isEmpty ? null : _unitList.first,
                    onChanged: (newValue) {
                      if (newValue == null) return;
                      setState(() {
                        _unitList
                          ..clear()
                          ..add(newValue);
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                TextButton(
                  onPressed: _unitList.isEmpty
                      ? null
                      : () {
                          List<UnitRef> unitRefList = List.empty(
                            growable: true,
                          );
                          for (String unitName in _unitList) {
                            UnitRef? unit = nameToUnitRef[unitName];
                            if (unit != null) {
                              unitRefList.add(unit);
                            }
                          }
                          widget.onSave.call(unitRefList);
                          Navigator.of(context).pop();
                        },
                  child: Text(
                    widget.displayOnlyBuiltinUnits
                        ? AppLocalizations.of(context)!.open
                        : AppLocalizations.of(context)!.save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
