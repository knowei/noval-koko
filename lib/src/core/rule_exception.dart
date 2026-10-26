/// 规则执行 / 网络请求过程中可展示给用户的异常。
class RuleException implements Exception {
  RuleException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() =>
      detail == null ? message : '$message\n${detail!}';
}
