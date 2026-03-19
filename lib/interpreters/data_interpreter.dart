import 'package:flutter/material.dart';

import '../databeans/code.dart';
import '../databeans/code_info.dart';
import '../databeans/key_value.dart';

abstract class DataInterpreter extends StatefulWidget {
  final KeyValue keyValue;
  final Code? codeData;
  final CodeInfo? codeInfo;
  final Function(DataInterpreter, String)? onLineDataChange;
  final int lineNumber;
  final bool displayLineNumber;
  final bool displayOperationOptions;
  final String? arguments;
  final bool overRiderValue;
  final bool readOnly;

  const DataInterpreter({
    super.key,
    required this.keyValue,
    required this.onLineDataChange,
    required this.lineNumber,
    required this.overRiderValue,
    this.codeData,
    this.codeInfo,
    this.arguments,
    required this.readOnly,
    required this.displayLineNumber,
    required this.displayOperationOptions,
  });
}
