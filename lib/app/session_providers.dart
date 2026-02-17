import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/shop_repo.dart';
import 'package:household_rpg/data/repositories/task_v2_repo.dart';
import 'package:household_rpg/data/repositories/user_repo.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

final fsUserRepoProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(firestoreProvider));
});

final shopRepoProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(ref.read(firestoreProvider));
});

final taskV2RepoProvider = Provider<TaskV2Repository>((ref) {
  return TaskV2Repository(ref.read(firestoreProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(firebaseAuthProvider).authStateChanges();
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final auth = ref.read(firebaseAuthProvider);
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
  await ref.read(fsUserRepoProvider).ensureUserDoc(auth.currentUser!.uid);
});

final currentUserProvider = StreamProvider<UserProfile?>((ref) {
  final _ = ref.watch(sessionBootstrapProvider);
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();
  return ref.read(fsUserRepoProvider).watchUser(uid);
});

final usersInMyGuildProvider = StreamProvider<List<UserProfile>>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me?.guildId == null) return const Stream.empty();
  return ref.read(fsUserRepoProvider).watchUsersByGuild(me!.guildId!);
});

final guildShopItemsProvider =
    StreamProvider.autoDispose.family<List<ShopItem>, String>((ref, guildId) {
  return ref.read(shopRepoProvider).watchGuildShopItems(guildId);
});

final weekTaskInstancesProvider = StreamProvider.autoDispose<List<TaskInstance>>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me?.guildId == null) return const Stream.empty();
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  final end = start.add(const Duration(days: 7, hours: 23, minutes: 59));
  return ref.read(taskV2RepoProvider).watchInstancesInRange(
        guildId: me!.guildId!,
        start: start,
        end: end,
      );
});

final taskTemplatesProvider = StreamProvider.autoDispose<List<TaskTemplate>>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me?.guildId == null) return const Stream.empty();
  return ref.read(taskV2RepoProvider).watchTemplates(me!.guildId!);
});

final taskEventsProvider = StreamProvider.autoDispose<List<TaskEvent>>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me?.guildId == null) return const Stream.empty();
  return ref.read(taskV2RepoProvider).watchRecentEvents(me!.guildId!);
});
