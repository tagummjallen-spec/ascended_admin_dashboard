import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseDate(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw != null) return DateTime.tryParse(raw.toString());
  return null;
}

class SupportChat {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String lastSender;
  final int unreadByAdmin;
  final int unreadByCustomer;
  final String status;

  const SupportChat({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.lastMessage,
    required this.lastSender,
    this.lastMessageAt,
    this.unreadByAdmin = 0,
    this.unreadByCustomer = 0,
    this.status = 'open',
  });

  factory SupportChat.fromDoc(DocumentSnapshot doc) {
    final map = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return SupportChat(
      id: doc.id,
      userId: map['userId']?.toString() ?? doc.id,
      userName: map['userName']?.toString() ?? 'Customer',
      userEmail: map['userEmail']?.toString() ?? '',
      lastMessage: map['lastMessage']?.toString() ?? '',
      lastMessageAt: _parseDate(map['lastMessageAt']),
      lastSender: map['lastSender']?.toString() ?? '',
      unreadByAdmin: (map['unreadByAdmin'] as num?)?.toInt() ?? 0,
      unreadByCustomer: (map['unreadByCustomer'] as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? 'open',
    );
  }
}

class SupportMessage {
  final String id;
  final String senderId;
  final String senderRole;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  factory SupportMessage.fromDoc(DocumentSnapshot doc) {
    final map = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return SupportMessage(
      id: doc.id,
      senderId: map['senderId']?.toString() ?? '',
      senderRole: map['senderRole']?.toString() ?? 'customer',
      senderName: map['senderName']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      createdAt: _parseDate(map['createdAt']),
    );
  }
}
