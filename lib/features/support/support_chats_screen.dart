import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/support_models.dart';
import '../../services/support_chat_service.dart';

class SupportChatsScreen extends StatefulWidget {
  const SupportChatsScreen({super.key});

  @override
  State<SupportChatsScreen> createState() => _SupportChatsScreenState();
}

class _SupportChatsScreenState extends State<SupportChatsScreen> {
  final _service = AdminSupportChatService();
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedChatId;
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectChat(String chatId) {
    setState(() => _selectedChatId = chatId);
    _service.markReadByAdmin(chatId);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      _scrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final chatId = _selectedChatId;
    final text = _replyController.text.trim();
    if (chatId == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendAdminMessage(chatId: chatId, text: text);
      _replyController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day} $h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Support',
          style: TextStyle(color: AppColors.primaryText, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'View active user chats and reply in real time',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                // Left: chat list
                SizedBox(
                  width: 340,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: AppColors.border)),
                    ),
                    child: StreamBuilder<List<SupportChat>>(
                      stream: _service.watchChats(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Error: ${snap.error}',
                                  style: const TextStyle(color: AppColors.error)),
                            ),
                          );
                        }
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final chats = snap.docsList;
                        if (chats.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No support chats yet.',
                                style: TextStyle(color: AppColors.secondaryText),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: chats.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, i) {
                            final chat = chats[i];
                            final selected = chat.id == _selectedChatId;
                            return Material(
                              color: selected
                                  ? AppColors.primaryAccent.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              child: InkWell(
                                onTap: () => _selectChat(chat.id),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            AppColors.primaryAccent.withValues(alpha: 0.2),
                                        foregroundColor: AppColors.primaryAccent,
                                        child: Text(
                                          (chat.userName.isNotEmpty ? chat.userName[0] : 'U')
                                              .toUpperCase(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    chat.userName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: AppColors.primaryText,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                if (chat.unreadByAdmin > 0)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primaryAccent,
                                                      borderRadius: BorderRadius.circular(999),
                                                    ),
                                                    child: Text(
                                                      '${chat.unreadByAdmin}',
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              chat.lastMessage.isNotEmpty
                                                  ? chat.lastMessage
                                                  : (chat.userEmail.isNotEmpty
                                                      ? chat.userEmail
                                                      : 'No messages yet'),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: AppColors.secondaryText, fontSize: 12),
                                            ),
                                            if (chat.lastMessageAt != null)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  _formatTime(chat.lastMessageAt),
                                                  style: const TextStyle(
                                                      color: AppColors.tertiaryText, fontSize: 10),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                // Right: chat window
                Expanded(
                  child: _selectedChatId == null
                      ? const Center(
                          child: Text(
                            'Select a chat to view messages',
                            style: TextStyle(color: AppColors.secondaryText),
                          ),
                        )
                      : _ChatWindow(
                          chatId: _selectedChatId!,
                          service: _service,
                          replyController: _replyController,
                          scrollController: _scrollController,
                          sending: _sending,
                          onSend: _send,
                          onMessagesLoaded: _scrollToBottom,
                          formatTime: _formatTime,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Small helper to avoid analyzer confusion with StreamBuilder generic access.
extension on AsyncSnapshot<List<SupportChat>> {
  List<SupportChat> get docsList => data ?? const <SupportChat>[];
}

class _ChatWindow extends StatelessWidget {
  final String chatId;
  final AdminSupportChatService service;
  final TextEditingController replyController;
  final ScrollController scrollController;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onMessagesLoaded;
  final String Function(DateTime?) formatTime;

  const _ChatWindow({
    required this.chatId,
    required this.service,
    required this.replyController,
    required this.scrollController,
    required this.sending,
    required this.onSend,
    required this.onMessagesLoaded,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header: chat metadata
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: StreamBuilder<List<SupportChat>>(
            stream: service.watchChats(),
            builder: (context, snap) {
              final chat = (snap.data ?? const [])
                  .where((c) => c.id == chatId)
                  .cast<SupportChat?>()
                  .firstWhere((_) => true, orElse: () => null);
              if (chat == null) {
                return const Text('Chat', style: TextStyle(color: AppColors.primaryText));
              }
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chat.userName,
                          style: const TextStyle(
                              color: AppColors.primaryText, fontWeight: FontWeight.w600),
                        ),
                        if (chat.userEmail.isNotEmpty)
                          Text(chat.userEmail,
                              style: const TextStyle(
                                  color: AppColors.secondaryText, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (chat.status == 'open' ? AppColors.success : AppColors.secondaryText)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      chat.status.toUpperCase(),
                      style: TextStyle(
                        color: chat.status == 'open' ? AppColors.success : AppColors.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // Messages
        Expanded(
          child: StreamBuilder<List<SupportMessage>>(
            stream: service.watchMessages(chatId),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(color: AppColors.error)));
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final messages = snap.data!;
              if (messages.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) => onMessagesLoaded());
              }
              if (messages.isEmpty) {
                return const Center(
                  child: Text('No messages in this chat yet.',
                      style: TextStyle(color: AppColors.secondaryText)),
                );
              }
              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  final isAdmin = m.senderRole == 'admin';
                  return Align(
                    alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: const BoxConstraints(maxWidth: 520),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? AppColors.primaryAccent.withValues(alpha: 0.2)
                            : AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isAdmin
                              ? AppColors.primaryAccent.withValues(alpha: 0.4)
                              : AppColors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAdmin ? (m.senderName.isNotEmpty ? m.senderName : 'Support') : m.senderName,
                            style: TextStyle(
                              color: isAdmin ? AppColors.lightAccent : AppColors.primaryAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(m.text,
                              style: const TextStyle(color: AppColors.primaryText, height: 1.35)),
                          const SizedBox(height: 4),
                          Text(formatTime(m.createdAt),
                              style:
                                  const TextStyle(color: AppColors.tertiaryText, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Reply box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
            color: AppColors.primaryBackground,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: replyController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: const TextStyle(color: AppColors.primaryText),
                  decoration: InputDecoration(
                    hintText: 'Type a reply...',
                    hintStyle: const TextStyle(color: AppColors.tertiaryText),
                    filled: true,
                    fillColor: AppColors.secondarySurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(sending ? 'Sending' : 'Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
