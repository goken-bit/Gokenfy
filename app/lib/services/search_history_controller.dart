import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_service.dart';

/// Persisted list of recent search terms (most recent first).
class SearchHistoryController extends StateNotifier<List<String>> {
  SearchHistoryController(this._storage) : super(const []);

  static const int _maxEntries = 20;

  final StorageService _storage;

  Future<void> load() async {
    state = await _storage.loadSearchHistory();
  }

  /// Adds a search term (deduplicated, most recent first) and persists it.
  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final next = [q, ...state.where((e) => e != q)];
    if (next.length > _maxEntries) next.removeRange(_maxEntries, next.length);
    state = next;
    await _storage.saveSearchHistory(next);
  }

  /// Removes a single entry and persists.
  Future<void> remove(String query) async {
    final next = state.where((e) => e != query).toList();
    state = next;
    await _storage.saveSearchHistory(next);
  }

  /// Clears all history and persists.
  Future<void> clear() async {
    state = const [];
    await _storage.saveSearchHistory(const []);
  }
}
