import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart'; // ✅ BELANGRIJK
import 'package:household_rpg/data/models/Quest.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/quest_repo.dart';

class QuestState {
  final List<Quest> dailies;
  final List<Quest> coops;
  final bool loading;
  final String? error;

  const QuestState({
    required this.dailies,
    required this.coops,
    this.loading = false,
    this.error,
  });

  static const empty = QuestState(dailies: [], coops: []);

  QuestState copyWith({
    List<Quest>? dailies,
    List<Quest>? coops,
    bool? loading,
    String? error,
  }) {
    return QuestState(
      dailies: dailies ?? this.dailies,
      coops: coops ?? this.coops,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class QuestController extends StateNotifier<QuestState> {
  QuestController(this._repo, {UserProfile? initialUser})
      : _user = initialUser,
        super(QuestState.empty) {
    if (_user != null) _subscribe();
  }

  final QuestRepository _repo;
  UserProfile? _user;
  StreamSubscription? _dailySub;
  StreamSubscription? _coopSub;

  void setUser(UserProfile? user) {
    if (user == null) return;
    final changed = _user?.id != user.id || _user?.guildId != user.guildId;
    if (!changed) return;
    _user = user;
    _subscribe();
  }

Future<void> refresh() async {
  if (_user == null) return;
  _subscribe();
}
  void _subscribe() {
    final u = _user;
    if (u == null) return;

    _dailySub?.cancel();
    _coopSub?.cancel();

    state = state.copyWith(loading: true, error: null);

    _dailySub = _repo.watchDailyQuests(u).listen(
      (dailies) => state = state.copyWith(dailies: dailies, loading: false),
      onError: (e) => state = state.copyWith(loading: false, error: e.toString()),
    );

    _coopSub = _repo.watchCoopQuests(u).listen(
      (coops) => state = state.copyWith(coops: coops, loading: false),
      onError: (e) => state = state.copyWith(loading: false, error: e.toString()),
    );
  }

  @override
  void dispose() {
    _dailySub?.cancel();
    _coopSub?.cancel();
    super.dispose();
  }

  bool get hasUser => _user != null;

  Future<void> completeDaily(String id) async {
    await _repo.completeDaily(questId: id, user: _user!);
    // geen refresh nodig — stream pikt de wijziging automatisch op
  }

  Future<void> contribute(String id, double delta) async {
    await _repo.contributeCoop(questId: id, user: _user!, delta: delta);
  }

  Future<void> claim(String id) async {
    await _repo.claimCoop(questId: id, user: _user!);
  }
}