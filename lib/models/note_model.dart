import 'dart:convert';

// Sentinel value for copyWith to distinguish between null and not provided
const _undefined = Object();

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageBase64; // Base64 encoded image
  final List<List<double>>?
  signaturePoints; // Signature coordinates as list of [x, y]

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.imageBase64,
    this.signaturePoints,
  });

  /// Convert Note to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imageBase64': imageBase64,
      'signaturePoints': signaturePoints,
    };
  }

  /// Create Note from JSON
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      imageBase64: json['imageBase64'] as String?,
      signaturePoints: json['signaturePoints'] != null
          ? List<List<double>>.from(
              (json['signaturePoints'] as List).map(
                (point) => List<double>.from(
                  (point as List).map((e) => (e as num).toDouble()),
                ),
              ),
            )
          : null,
    );
  }

  /// Copy with changes
  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    dynamic imageBase64 = _undefined,
    dynamic signaturePoints = _undefined,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageBase64: identical(imageBase64, _undefined)
          ? this.imageBase64
          : imageBase64,
      signaturePoints: identical(signaturePoints, _undefined)
          ? this.signaturePoints
          : signaturePoints,
    );
  }

  @override
  String toString() {
    return 'Note(id: $id, title: $title, content: $content, createdAt: $createdAt, updatedAt: $updatedAt, hasImage: ${imageBase64 != null}, hasSignature: ${signaturePoints != null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.imageBase64 == imageBase64 &&
        other.signaturePoints == signaturePoints;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        content.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        imageBase64.hashCode ^
        signaturePoints.hashCode;
  }
}

/// Utility function to encode List of Notes to JSON string
String encodeNotes(List<Note> notes) {
  return jsonEncode(notes.map((note) => note.toJson()).toList());
}

/// Utility function to decode JSON string to List of Notes
List<Note> decodeNotes(String json) {
  final List<dynamic> decoded = jsonDecode(json);
  return decoded
      .map((item) => Note.fromJson(item as Map<String, dynamic>))
      .toList();
}
