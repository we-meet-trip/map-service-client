import 'package:flutter/material.dart';

class ChatParticipant {
  final String id;
  final String name;
  final Color avatarColor;

  const ChatParticipant({
    required this.id,
    required this.name,
    required this.avatarColor,
  });
}
