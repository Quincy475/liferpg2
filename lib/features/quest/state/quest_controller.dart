import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:household_rpg/data/models/Quest.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/quest_repo.dart';

class QuestState {
  final List<Quest> dailies;
  final List<Quest> coops;
  final bool loading;
  final String? error;

  const QuestState({required this.dailies, required this.coops, this.loading = false, this.error});
  static const empty = QuestState(dailies: [], coops: []);

  QuestState copyWith({List<Quest>? dailies, List<Quest>? coops, bool? loading, String? error}) =>
      QuestState(
          dailies: dailies ?? this.dailies,
          coops: coops ?? this.coops,
          loading: loading ?? this.loading,
          error: error);
}

class QuestController extends StateNotifier<QuestState> {
  QuestController(this._repo, {UserProfile? initialUser})
      : _user = initialUser,
        super(QuestState.empty) {
    if (_user != null) refresh();
  }

  final QuestRepository _repo;
  UserProfile? _user;

  void setUser(UserProfile? user) {
    if (user == null) return;
    final changed = _user?.id != user.id || _user?.guildId != user.guildId;
    if (!changed) return;
    _user = user;
    refresh();
  }

  bool get hasUser => _user != null;

  Future<void> refresh() async {
    final u = _user;
    if (u == null) return;
    try {
      state = state.copyWith(loading: true, error: null);
      final d = await _repo.getDailyQuests(u);
      final c = await _repo.getCoopQuests(u);
      state = state.copyWith(dailies: d, coops: c, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
  
  Future<void> completeDaily(String id) async {
    print('complete');
    await _repo.completeDaily(questId: id, user: _user!);
    await refresh();
  }

  Future<void> contribute(String id, double delta) async {
    await _repo.contributeCoop(questId: id, user: _user!, delta: delta);
    await refresh();
  }

  Future<void> claim(String id) async {
    await _repo.claimCoop(questId: id, user: _user!);
    await refresh();
  }

  // Future<void> seedTasksForGuild() async {
  //   print('ietsss');
  //   print('user $_user h');
  //   await _repo.seedLeftColumnDefaults(guildId: _user!.guildId!);
  // }
}

// final questRepoProvider = Provider<QuestRepository>((ref) => DemoQuestRepo());
