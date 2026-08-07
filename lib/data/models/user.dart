class User {
  final String id;
  final String name;
  final String? profileImagePath;

  const User({
    required this.id,
    required this.name,
    this.profileImagePath,
  });
}
