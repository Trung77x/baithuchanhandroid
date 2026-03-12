import 'dart:convert';

// Sentinel value for copyWith to distinguish between null and not provided
const _undefined = Object();

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageBase64; // Base64 encoded image (legacy/local)
  final String? imageUrl; // Cloudinary image URL
  final List<List<double>>?
  signaturePoints; // Signature coordinates as list of [x, y]

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.imageBase64,
    this.imageUrl,
    this.signaturePoints,
  });

  /// Whether this note has an image (either URL or base64)
  bool get hasImage => imageUrl != null || imageBase64 != null;

  /// Convert Note to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imageBase64': imageBase64,
      'imageUrl': imageUrl,
      'signaturePoints': signaturePoints?.map((p) => [p[0], p[1]]).toList(),
    };
  }

  /// Parse a DateTime from either a String or a Firestore Timestamp
  static DateTime _parseDateTime(dynamic value) {
    if (value is String) return DateTime.parse(value);
    if (value is DateTime) return value;
    // Firestore Timestamp has toDate()
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Create Note from JSON (supports Firestore Timestamp fields)
  factory Note.fromJson(Map<String, dynamic> json) {
    List<List<double>>? sigPoints;
    try {
      final raw = json['signaturePoints'];
      if (raw != null && raw is List && raw.isNotEmpty) {
        sigPoints = raw.map<List<double>>((point) {
          final p = point as List;
          return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
        }).toList();
      }
    } catch (e) {
      sigPoints = null;
    }

    return Note(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      imageBase64: json['imageBase64'] as String?,
      imageUrl: json['imageUrl'] as String?,
      signaturePoints: sigPoints,
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
    dynamic imageUrl = _undefined,
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
      imageUrl: identical(imageUrl, _undefined) ? this.imageUrl : imageUrl,
      signaturePoints: identical(signaturePoints, _undefined)
          ? this.signaturePoints
          : signaturePoints,
    );
  }

  @override
  String toString() {
    return 'Note(id: $id, title: $title, content: $content, createdAt: $createdAt, updatedAt: $updatedAt, hasImage: $hasImage, imageUrl: $imageUrl, hasSignature: ${signaturePoints != null})';
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
        other.imageUrl == imageUrl &&
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
        imageUrl.hashCode ^
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
