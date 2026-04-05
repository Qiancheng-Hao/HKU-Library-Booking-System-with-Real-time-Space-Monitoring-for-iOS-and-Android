import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_session_provider.dart';

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Init session only if none exists yet — preserves existing conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AiSessionProvider>();
      if (!provider.hasSession && !provider.isLoading) {
        provider.initSession();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _inputController.clear();
    await context.read<AiSessionProvider>().sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiSessionProvider>(
      builder: (context, provider, _) {
        _scrollToBottom();
        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy_outlined, color: Colors.teal),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI Booking Assistant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.teal),
                    tooltip: 'New conversation',
                    onPressed: provider.isLoading
                        ? null
                        : () => provider.resetSession(),
                  ),
                ],
              ),
            ),

            if (provider.sessionError)
              Expanded(child: _buildErrorState(provider))
            else ...[
              Expanded(child: _buildMessageList(provider)),
              if (provider.awaitingConfirmation &&
                  provider.pendingConfirmation != null)
                _buildConfirmationCard(provider, provider.pendingConfirmation!),
              _buildInputBar(provider),
            ],
          ],
        );
      },
    );
  }

  Widget _buildErrorState(AiSessionProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Failed to connect to AI service'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.initSession(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(AiSessionProvider provider) {
    if (provider.messages.isEmpty && provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final itemCount = provider.messages.length + (provider.isLoading ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == provider.messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(provider.messages[index]);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Padding(
              padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final readyForConfirmation =
        (msg.data?['readyForConfirmation'] as bool?) ?? false;
    final showSuggestionChips =
        !msg.isUser && msg.data != null && !readyForConfirmation;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: msg.isResult ? Colors.green : Colors.teal,
              child: Icon(
                msg.isResult ? Icons.check : Icons.smart_toy_outlined,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: msg.isUser
                        ? Colors.teal
                        : msg.isResult
                        ? Colors.green[50]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: msg.isUser
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: msg.isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                    border: msg.isResult
                        ? Border.all(color: Colors.green.shade300)
                        : null,
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: msg.isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (showSuggestionChips) _buildSuggestionChips(msg.data!),
              ],
            ),
          ),
          if (msg.isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips(Map<String, dynamic> data) {
    final opts = data['suggestedOptions'] as Map<String, dynamic>?;
    if (opts == null) return const SizedBox.shrink();
    final locations =
        (opts['locations'] as List<dynamic>?)?.cast<String>().toList() ?? [];
    final roomTypes =
        (opts['room_types'] as List<dynamic>?)?.cast<String>().toList() ?? [];
    final rooms =
        (opts['rooms'] as List<dynamic>?)?.cast<String>().toList() ?? [];

    locations.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    roomTypes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    rooms.sort(_naturalOptionCompare);

    final all = [...locations, ...roomTypes, ...rooms];
    if (all.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: all
            .map(
              (option) => GestureDetector(
                onTap: () => _sendMessage(option),
                child: Chip(
                  label: Text(
                    option,
                    style: const TextStyle(fontSize: 12, color: Colors.teal),
                  ),
                  backgroundColor: Colors.teal.withValues(alpha: 0.08),
                  side: const BorderSide(color: Colors.teal, width: 0.8),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  int _naturalOptionCompare(String a, String b) {
    final tokenA = a.trim();
    final tokenB = b.trim();

    final numA = int.tryParse(tokenA);
    final numB = int.tryParse(tokenB);
    if (numA != null && numB != null) {
      return numA.compareTo(numB);
    }

    final reg = RegExp(r'^([A-Za-z]+)(\d+)$');
    final matchA = reg.firstMatch(tokenA);
    final matchB = reg.firstMatch(tokenB);
    if (matchA != null && matchB != null) {
      final prefixCompare = matchA
          .group(1)!
          .toLowerCase()
          .compareTo(matchB.group(1)!.toLowerCase());
      if (prefixCompare != 0) {
        return prefixCompare;
      }
      return int.parse(matchA.group(2)!).compareTo(int.parse(matchB.group(2)!));
    }

    return tokenA.toLowerCase().compareTo(tokenB.toLowerCase());
  }

  Widget _buildConfirmationCard(
    AiSessionProvider provider,
    Map<String, dynamic> preview,
  ) {
    final library = preview['library'] as String? ?? 'N/A';
    final date = preview['date'] as String? ?? 'N/A';
    final timeRanges =
        (preview['time_ranges'] as List<dynamic>?)?.cast<String>() ?? [];
    final candidateRooms =
        (preview['candidate_rooms'] as List<dynamic>?)?.cast<String>() ?? [];
    final libraryFacilityLabel = candidateRooms.isNotEmpty
        ? '$library - ${candidateRooms.join(', ')}'
        : library;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.teal, size: 18),
              SizedBox(width: 6),
              Text(
                'Booking Preview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _previewRow(Icons.local_library, libraryFacilityLabel),
          _previewRow(Icons.calendar_today, date),
          if (timeRanges.isNotEmpty)
            _previewRow(Icons.access_time, timeRanges.join(', ')),
          if (candidateRooms.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Booking facility:',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: candidateRooms
                  .map(
                    (room) => Chip(
                      label: Text(room, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.teal),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => provider.cancelConfirmation(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[400]!),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => provider.confirmBooking(candidateRooms),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.teal),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildInputBar(AiSessionProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              onSubmitted: _sendMessage,
              enabled: !provider.isLoading && provider.hasSession,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Type your request...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.teal,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: provider.isLoading
                  ? null
                  : () => _sendMessage(_inputController.text),
            ),
          ),
        ],
      ),
    );
  }
}
