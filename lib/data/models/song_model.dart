class Song {
  final String id;
  final String title;
  final String author;
  final DateTime addedDate;
  final DateTime lastActivity;

  Song({
    required this.id,
    required this.title,
    required this.author,
    required this.addedDate,
    required this.lastActivity,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'added_date': addedDate.toIso8601String(),
      'last_activity': lastActivity.toIso8601String(),
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      addedDate: DateTime.parse(json['added_date'] as String),
      lastActivity: DateTime.parse(json['last_activity'] as String),
    );
  }

  @override
  String toString() {
    return 'Song(id: $id, title: $title, author: $author)';
  }
}
