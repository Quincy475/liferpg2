import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/scoring/scoring_enginge.dart';

import 'data/repositories/task_repo.dart';
import 'data/repositories/event_repo.dart';
import 'data/repositories/raid_repo.dart';
// ⬆️ bovenaan
import 'package:flutter/material.dart';
import 'data/local/hive_boxes.dart';

// class QuestState {
//   final List<Quest> dailies;
//   final List<Quest> coops;
//   final bool loading;
//   final String? error;

//   const QuestState({
//     required this.dailies,
//     required this.coops,
//     this.loading = false,
//     this.error,
//   });

//   QuestState copyWith({
//     List<Quest>? dailies,
//     List<Quest>? coops,
//     bool? loading,
//     String? error,
//   }) {
//     return QuestState(
//       dailies: dailies ?? this.dailies,
//       coops: coops ?? this.coops,
//       loading: loading ?? this.loading,
//       error: error,
//     );
//   }

//   static const empty = QuestState(dailies: [], coops: [], loading: false);
// }

// class QuestController extends StateNotifier<QuestState> {
//   QuestController(this._repo, this._user) : super(QuestState.empty) {
//     refresh();
//   }
//   final QuestRepository _repo;
//   final UserProfile _user;

//   Future<void> refresh() async {
//     try {
//       state = state.copyWith(loading: true, error: null);
//       final d = await _repo.getDailyQuests(_user);
//       final c = await _repo.getCoopQuests(_user);
//       state = state.copyWith(dailies: d, coops: c, loading: false);
//     } catch (e) {
//       state = state.copyWith(loading: false, error: e.toString());
//     }
//   }

//   Future<void> completeDaily(String questId) async {
//     await _repo.completeDaily(questId: questId, user: _user);
//     await refresh();
//   }

//   Future<void> contribute(String questId, double delta) async {
//     await _repo.contributeCoop(questId: questId, user: _user, delta: delta);
//     await refresh();
//   }

//   Future<void> claim(String questId) async {
//     await _repo.claimCoop(questId: questId,user: _user);
//     await refresh();
//   }
// }


class ThemeState {
  final ThemeMode mode;
  final Color seedColor;
  const ThemeState({required this.mode, required this.seedColor});

  ThemeState copyWith({ThemeMode? mode, Color? seedColor}) =>
      ThemeState(mode: mode ?? this.mode, seedColor: seedColor ?? this.seedColor);
}

final themeProvider = NotifierProvider<ThemeController, ThemeState>(ThemeController.new);

class ThemeController extends Notifier<ThemeState> {
  static const _kMode = 'theme_mode'; // 'system'|'light'|'dark'
  static const _kSeed = 'theme_seed'; // int color value

  @override
  ThemeState build() {
    final modeStr = (appBox.get(_kMode) as String?) ?? 'system';
    final seedInt = (appBox.get(_kSeed) as int?) ?? Colors.teal.value;
    return ThemeState(mode: _parseMode(modeStr), seedColor: Color(seedInt));
  }

  ThemeMode _parseMode(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final s = switch (mode) { ThemeMode.light => 'light', ThemeMode.dark => 'dark', _ => 'system' };
    await appBox.put(_kMode, s);
  }

  Future<void> setSeed(Color c) async {
    state = state.copyWith(seedColor: c);
    await appBox.put(_kSeed, c.value);
  }
}

final rngProvider = Provider<Random>((_) => Random());

final scoringEngineProvider =
    Provider<ScoringEngine>((ref) => ScoringEngine(ref.read(rngProvider)));

final taskRepoProvider = Provider<TaskRepository>((_) => TaskRepository());
// final fsUserRepoProvider = Provider<UserRepository>((_) => UserRepository());
// final shopRepoProvider = Provider<ShopRepository>((_) => ShopRepository());
final eventRepoProvider = Provider<EventRepository>((_) => EventRepository());
final raidRepoProvider = Provider<RaidRepository>((_) => RaidRepository());

/// App lifecycle / weekly reset
final appLifecycleProvider = NotifierProvider<AppLifecycle, bool>(AppLifecycle.new);

class AppLifecycle extends Notifier<bool> {
  @override
  bool build() => true;

  // Future<void> maybeResetWeek() async {
  //   await ref.read(fsUserRepoProvider).maybeWeeklyReset();
  //   await ref.read(raidRepoProvider).maybeWeeklyResetRaid();
  //   await ref.read(fsUserRepoProvider).expireWeeklyBadges();
  // }
}
