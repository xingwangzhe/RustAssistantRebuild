class OpenFileParameters {
  final String path;
  final bool readOnly;

  OpenFileParameters({required this.path, required this.readOnly});

  OpenFileParameters.fromJson(Map<String, dynamic> json)
    : path = json['path'] as String,
      readOnly = json['readOnly'] as bool;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['path'] = path;
    data['readOnly'] = readOnly;
    return data;
  }

  @override
  bool operator ==(Object other) {
    // 先判断是否是同一个对象
    if (identical(this, other)) return true;
    // 判断类型是否匹配
    if (other is! OpenFileParameters) return false;
    // 按照需求：仅通过path判断相等性
    return path == other.path;
  }

  @override
  int get hashCode => path.hashCode;
}
