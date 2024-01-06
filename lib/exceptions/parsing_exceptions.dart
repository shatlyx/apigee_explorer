class ProxyParsingException implements Exception {
  String cause;
  String? description;

  ProxyParsingException({required this.cause, this.description});
}