import 'package:hive/hive.dart';

part 'chat_rule.g.dart';

@HiveType(typeId: 0)
class ChatRule extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String text;

  @HiveField(2)
  final bool isPositive; // true = debe hacer, false = no debe hacer

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  ChatRule({
    required this.id,
    required this.text,
    required this.isPositive,
    required this.createdAt,
    required this.updatedAt,
  });

  ChatRule copyWith({
    String? id,
    String? text,
    bool? isPositive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatRule(
      id: id ?? this.id,
      text: text ?? this.text,
      isPositive: isPositive ?? this.isPositive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isPositive': isPositive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ChatRule.fromJson(Map<String, dynamic> json) {
    return ChatRule(
      id: json['id'] as String,
      text: json['text'] as String,
      isPositive: json['isPositive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'ChatRule(id: $id, text: $text, isPositive: $isPositive, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatRule &&
        other.id == id &&
        other.text == text &&
        other.isPositive == isPositive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        text.hashCode ^
        isPositive.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
