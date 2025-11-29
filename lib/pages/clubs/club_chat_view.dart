import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/chat_message.dart';
import '../../models/race_challenge.dart';
import '../../services/chat_service.dart';
import '../../widgets/message_bubble.dart';
import 'race_challenge_dialog.dart';
import 'race_challenge_detail_page.dart';

class ClubChatView extends StatefulWidget {
  final String clubId;

  const ClubChatView({
    Key? key,
    required this.clubId,
  }) : super(key: key);

  @override
  State<ClubChatView> createState() => _ClubChatViewState();
}

class _ClubChatViewState extends State<ClubChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _user = FirebaseAuth.instance.currentUser;
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await ChatService.instance.sendMessage(
        clubId: widget.clubId,
        content: content,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _showRaceChallengeDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const RaceChallengeDialog(),
    );

    if (result != null && mounted) {
      try {
        await ChatService.instance.createRaceChallenge(
          clubId: widget.clubId,
          type: result['type'] as ChallengeType,
          scheduledTime: result['scheduledTime'] as DateTime?,
          maxParticipants: result['maxParticipants'] as int,
          questionsCount: result['questionsCount'] as int,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Race challenge created!'),
              backgroundColor: Colors.green,
            ),
          );

          _scrollToBottom();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create challenge: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openRaceChallenge(String challengeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RaceChallengeDetailPage(
          clubId: widget.clubId,
          challengeId: challengeId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: ChatService.instance.getMessagesStream(widget.clubId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading messages: ${snapshot.error}'),
                );
              }

              final messages = snapshot.data ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'clubs.empty.noMessages'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'clubs.empty.startConversation'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Auto-scroll to bottom on new messages
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isOwnMessage = message.senderId == _user?.uid;

                  return MessageBubble(
                    key: ValueKey(message.messageId),
                    message: message,
                    isOwnMessage: isOwnMessage,
                    onRaceChallengePressed: message.raceChallengeId != null
                        ? () => _openRaceChallenge(message.raceChallengeId!)
                        : null,
                  );
                },
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark background like rest of app
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Race Challenge Button
            IconButton(
              onPressed: _showRaceChallengeDialog,
              icon: const Icon(Icons.emoji_events),
              color: const Color(0xFFE53935), // Bright red icon
              tooltip: 'Start a race challenge',
            ),
            const SizedBox(width: 8),
            // Message Input
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white), // White text
                decoration: InputDecoration(
                  hintText: 'clubs.chat.typeMessage'.tr(),
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2E2E2E), // Slightly lighter dark
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            // Send Button
            Material(
              color: const Color(0xFFE53935), // Bright red
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: _isSending ? null : _sendMessage,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
