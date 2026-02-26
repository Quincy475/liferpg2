// MERGED providers: auth/session + user stream + thema + rng + scoring + repos + quest controller

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Firebase
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Jouw domein
import 'package:household_rpg/data/models/Quest.dart'; // jouw Quest-model
import 'package:household_rpg/data/models/User_profile.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/models/pet.dart';
import 'package:household_rpg/data/models/skillNode.dart';
import 'package:household_rpg/data/repositories/pet_repo.dart';
import 'package:household_rpg/data/repositories/quest_repo.dart'; // jouw QuestRepository
import 'package:household_rpg/data/repositories/skill_node_repository.dart';
import 'package:household_rpg/data/repositories/skill_tree_repository.dart';
import 'package:household_rpg/data/repositories/auth_repo.dart';
import 'package:household_rpg/data/repositories/user_repo.dart';
import 'package:household_rpg/features/pet/data/furniture_repo.dart';
import 'package:household_rpg/features/quest/state/quest_controller.dart';
import 'package:household_rpg/features/skills/domain/node.dart';

import 'package:household_rpg/scoring/scoring_enginge.dart';

// Lokale repos (zoals je had)
import 'package:household_rpg/data/repositories/task_repo.dart';
import 'package:household_rpg/data/repositories/shop_repo.dart';
import 'package:household_rpg/data/repositories/event_repo.dart';
import 'package:household_rpg/data/repositories/raid_repo.dart';

// Hive (voor thema)
import 'package:household_rpg/data/local/hive_boxes.dart';

/// ---------------------------------------------------------------------------
/// Firebase singletons
/// ---------------------------------------------------------------------------
final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
final authRepoProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(firebaseAuthProvider)),
);

/// ---------------------------------------------------------------------------
/// UserRepository (Firestore) + auth state
/// ---------------------------------------------------------------------------
final fsUserRepoProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.read(firestoreProvider)),
);
final usersInMyGuildProvider = StreamProvider<List<UserProfile>>((ref) {
  final meAsync = ref.watch(currentUserProvider);
  return meAsync.when(
    data: (me) {
      if (me == null || me.guildId == null) {
        return const Stream<List<UserProfile>>.empty();
      }
      return ref.read(fsUserRepoProvider).watchUsersByGuild(me.guildId!);
    },
    loading: () => const Stream<List<UserProfile>>.empty(),
    error: (_, __) => const Stream<List<UserProfile>>.empty(),
  );
});

// Inventory stream voor de actieve user
final userInventoryProvider = StreamProvider<List<InventoryItem>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const Stream<List<InventoryItem>>.empty();
  return ref.read(fsUserRepoProvider).watchInventory(me.id);
});

/// Auth status (luistert naar in/uitloggen, ook bij upgrade van anonymous -> Google/Apple)
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.read(firebaseAuthProvider).authStateChanges(),
);

/// Bootstrap auth gekoppeld profiel: alleen bij ingelogde user user-doc syncen.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final authUser = await ref.watch(authStateProvider.future);
  if (authUser == null) return;
  final fallbackName = (authUser.displayName?.trim().isNotEmpty ?? false)
      ? authUser.displayName!.trim()
      : (authUser.email?.split('@').first ?? 'Player');
  await ref.read(fsUserRepoProvider).ensureUserDoc(authUser.uid, defaultName: fallbackName);
});

final petRepoProvider = Provider<PetRepository>((ref) {
  return PetRepository(FirebaseFirestore.instance);
});

/// Huidig uid
final currentUserIdProvider = Provider<String?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  return authUser?.uid;
});

final isAnonymousSessionProvider = Provider<bool>((ref) {
  return ref.watch(currentUserIdProvider) == null;
});

/// Live UserProfile uit Firestore (één stream app-breed gedeeld)
final currentUserProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();
  return Stream.fromFuture(ref.read(fsUserRepoProvider).ensureUserDoc(uid)).asyncExpand(
    (_) => ref.read(fsUserRepoProvider).watchUser(uid),
  );
});

final fsSkillTreeRepoProvider = Provider<SkillTreeRepository>(
  (ref) => SkillTreeRepository(FirebaseFirestore.instance),
);

final questControllerProvider = StateNotifierProvider<QuestController, QuestState>((ref) {
  // start bootstrappen (ingelogde user + ensureUserDoc)
  final boot = ref.watch(sessionBootstrapProvider);

  final repo = ref.watch(questRepoProvider);
  final meNow = ref.watch(currentUserProvider).value; // kan nog null zijn
  final controller = QuestController(repo, initialUser: meNow);

  // 1) luister naar user-wijzigingen (guild switch, profiel update)
  ref.listen<UserProfile?>(
    currentUserProvider.select((a) => a.valueOrNull),
    (prev, next) => controller.setUser(next),
    fireImmediately: true,
  );

  // 2) wanneer bootstrap klaar is, haal user nogmaals op en set hem
  ref.listen<AsyncValue<void>>(sessionBootstrapProvider, (prev, next) {
    if (next.hasValue) {
      final me = ref.read(currentUserProvider).value;
      controller.setUser(me);
    }
  });

  return controller;
});

// ---- Providers
final skillNodeRepoProvider = Provider<SkillNodeRepository>((ref) {
  final db = FirebaseFirestore.instance;
  return SkillNodeRepository(db);
});

final currentSkillNodesVersionProvider = FutureProvider<String>((ref) async {
  final repo = ref.read(skillNodeRepoProvider);
  final v = await repo.getCurrentVersion();
  return v;
});

final skillNodesProvider = StreamProvider.family<List<SkillNode>, SkillType>((ref, skill) async* {
  final repo = ref.read(skillNodeRepoProvider);
  final version = await ref.watch(currentSkillNodesVersionProvider.future);
  yield* repo.watchNodesForSkill(version: version, skill: skill);
});

final guildShopItemsProvider =
    StreamProvider.autoDispose.family<List<ShopItem>, String>((ref, guildId) {
  final repo = ref.read(shopRepoProvider);
  return repo.watchGuildShopItems(guildId);
});


// Pet state stream (kan null zijn als user nog geen pet koos)
// final petStateProvider = StreamProvider<PetState?>((ref) {
//   final uid = ref.watch(currentUserIdProvider);
//   if (uid == null) return const Stream.empty();
//   return ref.read(petRepoProvider).watchState(uid);
// });

// final roomLayoutProvider = StreamProvider<RoomLayout?>((ref) {
//   final uid = ref.watch(currentUserIdProvider);
//   if (uid == null) return const Stream.empty();
//   return ref.read(petRepoProvider).watchRoom(uid);
// });

/// ---------------------------------------------------------------------------
/// Thema (zoals je had), met hive-persist
/// ---------------------------------------------------------------------------
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

/// ---------------------------------------------------------------------------
/// Overige utilities/repo’s (zoals je had)
//  (legacy user repo laten we staan als je nog lokale calls gebruikt, maar probeer
//   stap voor stap over te zetten naar de Firestore user repo hierboven)
/// ---------------------------------------------------------------------------
final rngProvider = Provider<Random>((_) => Random());
final scoringEngineProvider =
    Provider<ScoringEngine>((ref) => ScoringEngine(ref.read(rngProvider)));

final taskRepoProvider = Provider<TaskRepository>((_) => TaskRepository());
// final legacyfsUserRepoProvider  = Provider<legacy_user_repo.UserRepository>((_) => legacy_user_repo.UserRepository());
final shopRepoProvider = Provider<ShopRepository>((ref) {
  final db = ref.read(firestoreProvider);
  return ShopRepository(db);
});
final eventRepoProvider = Provider<EventRepository>((_) => EventRepository());
final raidRepoProvider = Provider<RaidRepository>((_) => RaidRepository());

final furnitureReppoProvider  = Provider<FurnitureRepo>((_) => FurnitureRepo());
/// ---------------------------------------------------------------------------
/// Quest state + controller (nu met echte uid uit Firebase i.p.v. const 'me')
/// ---------------------------------------------------------------------------
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
//   QuestController(this._repo, this._userId) : super(QuestState.empty) {
//     // Als _userId leeg is, wachten we op bootstrap; anders meteen refresh
//     if (_userId.isNotEmpty) refresh();
//   }

//   final QuestRepository _repo;
//   final String _userId;

//   UserProfile? _user;
//   // String? _user = _user?.id;

//   /// Bootstrap / update user als deze later binnenkomt of wijzigt
//   void setUser(UserProfile user) {
//     final first = _user == null;
//     _user = user;
//     if (first) {
//       refresh();
//     } else {
//       // user switch → opnieuw laden
//       refresh();
//     }
//   }

//   Future<void> refresh() async {
//     print('refresh');
//     final u = _user;
//     if (u == null) return; // nog geen user bekend

//     try {
//       state = state.copyWith(loading: true, error: null);
//       final d = await _repo.getDailyQuests(u);
//       final c = await _repo.getCoopQuests(u);
//       state = state.copyWith(dailies: d, coops: c, loading: false);
//     } catch (e) {
//       state = state.copyWith(loading: false, error: e.toString());
//     }
//   }

//   Future<void> seedTasksForGuild() async {
//     print('SEEDING TASKS');
//     print(_user);
//     print(_userId);

//     // await _repo.seedLeftColumnDefaults(guildId: guildId, );
//   }

//   // Future<void> refresh() async {
//   //   if (_user.isEmpty) return; // wacht tot uid bekend is
//   //   try {
//   //     state = state.copyWith(loading: true, error: null);
//   //     final d = await _repo.getDailyQuests(_user);
//   //     final c = await _repo.getCoopQuests(_user);
//   //     state = state.copyWith(dailies: d, coops: c, loading: false);
//   //   } catch (e) {
//   //     state = state.copyWith(loading: false, error: e.toString());
//   //   }
//   // }

//   Future<void> completeDaily(String questId) async {
//     // if (_user) return;
//     // await _repo.completeDaily(questId, _user);
//     // await refresh();
//   }

//   Future<void> contribute(String questId, double delta) async {
//     // if (_user.isEmpty) return;
//     // await _repo.contributeCoop(questId, _user, delta);
//     // await refresh();
//   }

//   Future<void> claim(String questId) async {
//     // if (_user.isEmpty) return;
//     // await _repo.claimCoop(questId, _user);
//     // await refresh();
//   }
// }

/// Belangrijk: we wachten op `sessionBootstrapProvider` zodat er zeker een uid is.
/// Daarna lezen we het uid uit `currentUserIdProvider`. Verandert de uid (b.v. bij
/// upgrade/linken), dan wordt deze provider herbouwd met de nieuwe uid.

/// ---------------------------------------------------------------------------
/// App lifecycle placeholder (zoals je had)
/// ---------------------------------------------------------------------------
final appLifecycleProvider = NotifierProvider<AppLifecycle, bool>(AppLifecycle.new);

class AppLifecycle extends Notifier<bool> {
  @override
  bool build() => true;

  // Voorbeeld: weekly reset zou je hier via Cloud Function kunnen triggeren.
  // Future<void> maybeResetWeek() async { ... }
}
