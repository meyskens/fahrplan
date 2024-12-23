
extension StringExNullable on String? {

  bool get isNullOrEmpty => this == null || this!.isEmpty;

  bool get isNullOrBlank =>
      this == null || this!.isEmpty || this!.trim().isEmpty;

  bool get isNotNullOrEmpty => !isNullOrEmpty;
}