import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/player.dart';

/// Owns the in-memory list of players and mediates all player CRUD between the
/// UI and the database. Keeps the list sorted (primary user first, then
/// alphabetical) and notifies listeners on every change.
class PlayersProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;
  List<Player> _players = [];
  bool _loaded = false;

  /// The current players, sorted with the primary user first.
  List<Player> get players => _players;

  /// Whether the initial load from the database has completed.
  bool get loaded => _loaded;

  /// The device's primary user, or null if none set yet.
  Player? get primaryPlayer =>
      _players.where((p) => p.isPrimary).firstOrNull;

  /// Loads all players from the database and marks the provider as loaded.
  Future<void> load() async {
    _players = await _db.getPlayers();
    _sort();
    _loaded = true;
    notifyListeners();
  }

  /// Creates and persists a new player, optionally making them the primary
  /// user, and returns the saved record with its assigned id.
  Future<Player> addPlayer(String name, {bool isPrimary = false}) async {
    final player = Player(name: name, isPrimary: isPrimary);
    final id = await _db.insertPlayer(player);
    if (isPrimary) await _db.setPrimaryPlayer(id);
    final saved = Player(
      id: id,
      name: name,
      isPrimary: isPrimary,
    );
    _players = [..._players, saved];
    _sort();
    notifyListeners();
    return saved;
  }

  /// Persists changes to [player] and refreshes it in the in-memory list.
  Future<void> updatePlayer(Player player) async {
    await _db.updatePlayer(player);
    _players = _players.map((p) => p.id == player.id ? player : p).toList();
    _sort();
    notifyListeners();
  }

  /// Makes [player] the primary user, clearing the flag on all others.
  Future<void> setPrimary(Player player) async {
    await _db.setPrimaryPlayer(player.id!);
    _players = _players
        .map((p) => p.copyWith(isPrimary: p.id == player.id))
        .toList();
    _sort();
    notifyListeners();
  }

  /// Deletes the player with [id] (soft-delete in the DB) and drops it from the list.
  Future<void> deletePlayer(int id) async {
    await _db.deletePlayer(id);
    _players = _players.where((p) => p.id != id).toList();
    notifyListeners();
  }

  /// Returns the loaded player with [id], or null if not present.
  Player? getById(int id) {
    try {
      return _players.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Primary user always first, then alphabetical.
  void _sort() {
    _players.sort((a, b) {
      if (a.isPrimary && !b.isPrimary) return -1;
      if (!a.isPrimary && b.isPrimary) return 1;
      return a.name.compareTo(b.name);
    });
  }
}
