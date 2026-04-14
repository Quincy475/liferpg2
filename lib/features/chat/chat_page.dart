import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:household_rpg/data/models/enums.dart';
import 'package:household_rpg/data/models/task_suggestion.dart';
import 'package:household_rpg/data/repositories/task_mvp_repo.dart';
import 'package:household_rpg/services/ai_service.dart';
import 'package:household_rpg/app/session_providers.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum _SuggestionStatus { pending, accepted, rejected }

class _ChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final List<TaskSuggestion> suggestions;
  final Map<String, _SuggestionStatus> suggestionStatuses;
  final bool isLoading;

  const _ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    this.suggestions = const [],
    this.suggestionStatuses = const {},
    this.isLoading = false,
  });

  _ChatMessage copyWith({
    Map<String, _SuggestionStatus>? suggestionStatuses,
    bool? isLoading,
    String? text,
  }) =>
      _ChatMessage(
        id: id,
        isUser: isUser,
        text: text ?? this.text,
        suggestions: suggestions,
        suggestionStatuses: suggestionStatuses ?? this.suggestionStatuses,
        isLoading: isLoading ?? this.isLoading,
      );
}

class _ChatState {
  final List<_ChatMessage> messages;
  final bool isThinking;

  const _ChatState({this.messages = const [], this.isThinking = false});

  _ChatState copyWith({List<_ChatMessage>? messages, bool? isThinking}) =>
      _ChatState(
        messages: messages ?? this.messages,
        isThinking: isThinking ?? this.isThinking,
      );
}

class _ChatNotifier extends StateNotifier<_ChatState> {
  final AiService _ai;
  final TaskMvpRepository _taskRepo;
  final String _userId;
  final String? _guildId;

  _ChatNotifier({
    required AiService ai,
    required TaskMvpRepository taskRepo,
    required String userId,
    required String? guildId,
  })  : _ai = ai,
        _taskRepo = taskRepo,
        _userId = userId,
        _guildId = guildId,
        super(const _ChatState());

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = _ChatMessage(
      id: _newId(),
      isUser: true,
      text: text.trim(),
    );

    final loadingMsg = _ChatMessage(
      id: _newId(),
      isUser: false,
      text: '',
      isLoading: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, loadingMsg],
      isThinking: true,
    );

    final response = await _ai.parseTasks(
      userMessage: text.trim(),
      today: DateTime.now(),
    );

    final statuses = <String, _SuggestionStatus>{
      for (final s in response.suggestions)
        '${s.title}_${s.scheduleType.name}': _SuggestionStatus.pending,
    };

    final aiMsg = _ChatMessage(
      id: loadingMsg.id,
      isUser: false,
      text: response.message,
      suggestions: response.suggestions,
      suggestionStatuses: statuses,
    );

    final updated = state.messages.map((m) => m.id == loadingMsg.id ? aiMsg : m).toList();
    state = state.copyWith(messages: updated, isThinking: false);
  }

  Future<void> acceptSuggestion(String messageId, TaskSuggestion suggestion) async {
    final key = '${suggestion.title}_${suggestion.scheduleType.name}';
    _updateStatus(messageId, key, _SuggestionStatus.accepted);

    if (_guildId == null) return;

    try {
      await _taskRepo.createTemplate(
        guildId: _guildId!,
        input: suggestion.toTemplate(),
        actorUserId: _userId,
      );
      final now = DateTime.now();
      await _taskRepo.ensureUpcomingInstances(
        guildId: _guildId!,
        from: now,
        to: now.add(const Duration(days: 30)),
      );
    } catch (e) {
      _updateStatus(messageId, key, _SuggestionStatus.pending);
    }
  }

  void rejectSuggestion(String messageId, TaskSuggestion suggestion) {
    final key = '${suggestion.title}_${suggestion.scheduleType.name}';
    _updateStatus(messageId, key, _SuggestionStatus.rejected);
  }

  void _updateStatus(String messageId, String key, _SuggestionStatus status) {
    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      final newStatuses = {...m.suggestionStatuses, key: status};
      return m.copyWith(suggestionStatuses: newStatuses);
    }).toList();
    state = state.copyWith(messages: updated);
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString() +
      Random().nextInt(9999).toString();
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _aiServiceProvider = Provider<AiService>((_) => AiService());

final _chatProvider = StateNotifierProvider.autoDispose<_ChatNotifier, _ChatState>((ref) {
  final ai = ref.read(_aiServiceProvider);
  final taskRepo = ref.read(taskMvpRepoProvider);
  final user = ref.watch(currentUserProvider).value;
  return _ChatNotifier(
    ai: ai,
    taskRepo: taskRepo,
    userId: user?.id ?? '',
    guildId: user?.guildId,
  );
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(_chatProvider.notifier).send(text);
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(_chatProvider);
    final user = ref.watch(currentUserProvider).value;

    ref.listen<_ChatState>(_chatProvider, (_, next) {
      if (next.messages.isNotEmpty) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Planner'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          if (user?.guildId == null)
            _NoGuildBanner(),
          Expanded(
            child: chatState.messages.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, i) {
                      final msg = chatState.messages[i];
                      return msg.isUser
                          ? _UserBubble(msg.text)
                          : _AiBubble(
                              message: msg,
                              onAccept: (s) => ref
                                  .read(_chatProvider.notifier)
                                  .acceptSuggestion(msg.id, s),
                              onReject: (s) => ref
                                  .read(_chatProvider.notifier)
                                  .rejectSuggestion(msg.id, s),
                            );
                    },
                  ),
          ),
          _InputBar(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _NoGuildBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Je bent nog niet in een guild. Maak of join een guild via Profiel om taken te kunnen aanmaken.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: color.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Vertel me wat je wil doen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bijv: "Morgen koken en was doen. Elke dag sporten."',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(text, style: TextStyle(color: scheme.onPrimary)),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final _ChatMessage message;
  final void Function(TaskSuggestion) onAccept;
  final void Function(TaskSuggestion) onReject;

  const _AiBubble({
    required this.message,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isLoading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Even denken…',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(4),
                    topRight: const Radius.circular(16),
                    bottomLeft: message.suggestions.isEmpty
                        ? const Radius.circular(16)
                        : const Radius.circular(4),
                    bottomRight: const Radius.circular(16),
                  ),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              if (message.suggestions.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...message.suggestions.map((s) {
                  final key = '${s.title}_${s.scheduleType.name}';
                  final status = message.suggestionStatuses[key] ?? _SuggestionStatus.pending;
                  return _SuggestionCard(
                    suggestion: s,
                    status: status,
                    onAccept: () => onAccept(s),
                    onReject: () => onReject(s),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final TaskSuggestion suggestion;
  final _SuggestionStatus status;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _SuggestionCard({
    required this.suggestion,
    required this.status,
    required this.onAccept,
    required this.onReject,
  });

  IconData _skillIcon(SkillType skill) {
    switch (skill) {
      case SkillType.cooking:
        return Icons.restaurant;
      case SkillType.cleaning:
        return Icons.cleaning_services;
      case SkillType.fixing:
        return Icons.build;
      case SkillType.laundry:
        return Icons.local_laundry_service;
      case SkillType.admin:
        return Icons.assignment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDone = status != _SuggestionStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: status == _SuggestionStatus.accepted
          ? scheme.primaryContainer
          : status == _SuggestionStatus.rejected
              ? scheme.surfaceContainerHighest.withOpacity(0.5)
              : scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: status == _SuggestionStatus.accepted
              ? scheme.primary.withOpacity(0.4)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              _skillIcon(suggestion.skill),
              size: 20,
              color: isDone
                  ? scheme.onSurface.withOpacity(0.4)
                  : scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: status == _SuggestionStatus.rejected
                          ? TextDecoration.lineThrough
                          : null,
                      color: isDone
                          ? scheme.onSurface.withOpacity(0.5)
                          : scheme.onSurface,
                    ),
                  ),
                  Text(
                    '${suggestion.skill.label} · ${suggestion.scheduleLabel} · ${suggestion.coinsBase} coins',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            if (!isDone) ...[
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                color: scheme.primary,
                tooltip: 'Aanmaken',
                onPressed: onAccept,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                icon: const Icon(Icons.cancel_outlined),
                color: scheme.onSurface.withOpacity(0.4),
                tooltip: 'Overslaan',
                onPressed: onReject,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ] else
              Icon(
                status == _SuggestionStatus.accepted ? Icons.check_circle : Icons.cancel,
                size: 20,
                color: status == _SuggestionStatus.accepted
                    ? scheme.primary
                    : scheme.onSurface.withOpacity(0.3),
              ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Morgen koken, elke dag sporten…',
                  hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
