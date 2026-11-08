import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/support_models.dart';

class AdminSupportChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _chats => _firestore.collection('support_chats');
  CollectionReference _messages(String chatId) =>
      _chats.doc(chatId).collection('messages');

  Stream<List<SupportChat>> watchChats() {
    return _chats.snapshots().map((snap) {
      final chats = snap.docs.map((d) => SupportChat.fromDoc(d)).toList();
      chats.sort((a, b) {
        final at = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });
      return chats;
    });
  }

  Stream<List<SupportMessage>> watchMessages(String chatId) {
    return _messages(chatId).snapshots().map((snap) {
      final msgs = snap.docs.map((d) => SupportMessage.fromDoc(d)).toList();
      msgs.sort((a, b) {
        final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return at.compareTo(bt);
      });
      return msgs;
    });
  }

  Future<void> sendAdminMessage({
    required String chatId,
    required String text,
    String adminName = 'Support Team',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final chatRef = _chats.doc(chatId);
    final msgRef = _messages(chatId).doc();
    final batch = _firestore.batch();

    batch.set(msgRef, {
      'senderId': 'admin',
      'senderRole': 'admin',
      'senderName': adminName,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'readByAdmin': true,
      'readByCustomer': false,
    });

    batch.set(
      chatRef,
      {
        'lastMessage':
            trimmed.length > 120 ? '${trimmed.substring(0, 120)}…' : trimmed,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSender': 'admin',
        'unreadByCustomer': FieldValue.increment(1),
        'status': 'open',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    try {
      await batch.commit();
    } catch (e, st) {
      debugPrint('AdminSupportChatService.sendAdminMessage failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> markReadByAdmin(String chatId) async {
    try {
      final unread = await _messages(chatId)
          .where('senderRole', isEqualTo: 'customer')
          .where('readByAdmin', isEqualTo: false)
          .get();
      final batch = _firestore.batch();
      for (final d in unread.docs) {
        batch.update(d.reference, {'readByAdmin': true});
      }
      batch.set(
        _chats.doc(chatId),
        {'unreadByAdmin': 0, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (e, st) {
      debugPrint('AdminSupportChatService.markReadByAdmin failed: $e\n$st');
    }
  }

  Future<void> setChatStatus(String chatId, String status) async {
    await _chats.doc(chatId).set(
      {'status': status, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}
