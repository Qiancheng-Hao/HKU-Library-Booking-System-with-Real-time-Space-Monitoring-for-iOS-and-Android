import 'package:flutter/material.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../providers/ai_session_provider.dart';
import '../../../../theme/app_theme.dart';

class SuggestionChips extends StatelessWidget {
  final ChatMessage message;
  final AiChatResponse data;
  final bool disableMapShortcut;
  final bool selectedOnMap;
  final void Function(String) onSendMessage;
  final void Function(ChatMessage, AiChatResponse) onOpenMap;

  const SuggestionChips({
    super.key,
    required this.message,
    required this.data,
    this.disableMapShortcut = false,
    this.selectedOnMap = false,
    required this.onSendMessage,
    required this.onOpenMap,
  });

  int _naturalCompare(String a, String b) {
    final tokenA = a.trim();
    final tokenB = b.trim();
    final numA = int.tryParse(tokenA);
    final numB = int.tryParse(tokenB);
    if (numA != null && numB != null) return numA.compareTo(numB);

    final reg = RegExp(r'^([A-Za-z]+)(\d+)$');
    final matchA = reg.firstMatch(tokenA);
    final matchB = reg.firstMatch(tokenB);
    if (matchA != null && matchB != null) {
      final prefixCompare = matchA
          .group(1)!
          .toLowerCase()
          .compareTo(matchB.group(1)!.toLowerCase());
      if (prefixCompare != 0) return prefixCompare;
      return int.parse(matchA.group(2)!).compareTo(int.parse(matchB.group(2)!));
    }
    return tokenA.toLowerCase().compareTo(tokenB.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final opts = data.suggestedOptions;
    if (opts == null) return const SizedBox.shrink();

    final locations = [...opts.locations];
    final roomTypes = [...opts.roomTypes];
    final rooms = [...opts.rooms];

    locations.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    roomTypes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    rooms.sort(_naturalCompare);

    final nonRoomOptions = [...locations, ...roomTypes];
    if (nonRoomOptions.isEmpty && rooms.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nonRoomOptions.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: nonRoomOptions
                  .map(
                    (option) => GestureDetector(
                      onTap: () => onSendMessage(option),
                      child: Chip(
                        label: Text(
                          option,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                        backgroundColor: cs.secondaryContainer,
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (rooms.isNotEmpty) ...[
            if (nonRoomOptions.isNotEmpty) const SizedBox(height: 8),
            GestureDetector(
              onTap: disableMapShortcut ? null : () => onOpenMap(message, data),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: disableMapShortcut
                      ? cs.surfaceContainerHigh
                      : cs.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: disableMapShortcut
                        ? cs.outlineVariant
                        : cs.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 16,
                      color: disableMapShortcut
                          ? cs.onSurfaceVariant
                          : cs.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      disableMapShortcut
                          ? (selectedOnMap
                                ? 'Selected on Map'
                                : 'Map Options Expired')
                          : 'View on Map  (${rooms.length} available)',
                      style: tt.bodySmall?.copyWith(
                        color: disableMapShortcut
                            ? cs.onSurfaceVariant
                            : cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      disableMapShortcut
                          ? (selectedOnMap ? Icons.check_circle : Icons.block)
                          : Icons.chevron_right,
                      size: disableMapShortcut ? 14 : 16,
                      color: disableMapShortcut
                          ? cs.onSurfaceVariant
                          : cs.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
