class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.location,
  });

  final String id;
  final String name;
  final String location;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Branch && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
