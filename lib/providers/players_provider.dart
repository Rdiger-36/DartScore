import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/player.dart';

class PlayersProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;
  List<Player> _players = [];
  bool _loaded = false;

  List<Player> get players => _players;
  bool get loaded => _loaded;

  /// The device's primary user, or null if none set yet.
  Player? get primaryPlayer =>
      _players.where((p) => p.isPrimary).firstOrNull;

  Future<void> load() async {
    _players = await _db.getPlayers();
    _sort();
    _loaded = true;
    notifyListeners();
  }

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

  Future<void> updatePlayer(Player player) async {
    await _db.updatePlayer(player);
    _players = _players.map((p) => p.id == player.id ? player : p).toList();
    _sort();
    notifyListeners();
  }

  Future<void> setPrimary(Player player) async {
    await _db.setPrimaryPlayer(player.id!);
    _players = _players
        .map((p) => p.copyWith(isPrimary: p.id == player.id))
        .toList();
    _sort();
    notifyListeners();
  }

  Future<void> deletePlayer(int id) async {
    await _db.deletePlayer(id);
    _players = _players.where((p) => p.id != id).toList();
    notifyListeners();
  }

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
