import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../core/theme.dart';
import '../models/player_state.dart';
import '../models/song.dart';
import '../providers.dart';
import '../services/spotify_csv_importer.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final library = ref.read(libraryProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 60),
        children: [
          _SectionTitle('Playback'),
          _SliderTile(
            icon: Icons.speed,
            title: 'Playback speed',
            valueLabel: '${player.speed.toStringAsFixed(2)}×',
            value: ((player.speed - 0.5) / 1.5).clamp(0.0, 1.0),
            onChanged: (v) => notifier.setSpeed(0.5 + v * 1.5),
          ),
          _SliderTile(
            icon: Icons.volume_up,
            title: 'Volume boost',
            valueLabel: '${(player.volume * 100).round()}%',
            value: player.volume,
            onChanged: (v) => notifier.setVolume(v),
          ),
          SwitchListTile(
            secondary: const Icon(
              Icons.auto_awesome_motion,
              color: AppColors.textSecondary,
            ),
            title: const Text(
              'Autoplay',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
            subtitle: const Text(
              'Play similar songs when the queue ends',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            value: player.autoplay,
            activeTrackColor: AppColors.accent,
            onChanged: (_) => notifier.toggleAutoplay(),
          ),
          SwitchListTile(
            secondary: const Icon(
              Icons.fast_forward,
              color: AppColors.textSecondary,
            ),
            title: const Text(
              'Crossfade',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
            subtitle: const Text(
              'Fade between tracks',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            value: player.crossfade,
            activeTrackColor: AppColors.accent,
            onChanged: (_) => notifier.toggleCrossfade(),
          ),
          const Divider(),
          _SectionTitle('Sleep timer'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SleepChip(
                  label: 'Off',
                  active: player.sleepTimerRemaining == null,
                  onTap: () => notifier.cancelSleepTimer(),
                ),
                _SleepChip(
                  label: '15 min',
                  onTap: () =>
                      notifier.startSleepTimer(const Duration(minutes: 15)),
                ),
                _SleepChip(
                  label: '30 min',
                  onTap: () =>
                      notifier.startSleepTimer(const Duration(minutes: 30)),
                ),
                _SleepChip(
                  label: '45 min',
                  onTap: () =>
                      notifier.startSleepTimer(const Duration(minutes: 45)),
                ),
                _SleepChip(
                  label: '60 min',
                  onTap: () =>
                      notifier.startSleepTimer(const Duration(minutes: 60)),
                ),
              ],
            ),
          ),
          if (player.sleepTimerRemaining != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.bedtime, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Sleeping in ${notifier.sleepTimerLabel()}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          _SectionTitle('Library'),
          ListTile(
            leading: const Icon(Icons.history, color: AppColors.textSecondary),
            title: const Text(
              'Clear recently played',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
            onTap: () async {
              final ok = await _confirm(context, 'Clear history?');
              if (ok) await library.clearHistory();
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.settings_backup_restore,
              color: AppColors.textSecondary,
            ),
            title: const Text(
              'Backup & restore',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
            subtitle: const Text(
              'Save or load your library as text',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            onTap: () => _showBackupSheet(context),
          ),
          ListTile(
            leading: const Icon(
              Icons.import_export,
              color: AppColors.textSecondary,
            ),
            title: const Text(
              'Import from Spotify CSV',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
            subtitle: const Text(
              'Liked Songs export → new playlist',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            onTap: () => _importSpotifyCsv(context, ref),
          ),
          const Divider(),
          _SectionTitle('About'),
          const ListTile(
            leading: Icon(Icons.music_note, color: AppColors.accent),
            title: Text(
              'Gokenfy',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
            subtitle: Text(
              'Free music streaming · v0.1.0',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBackupSheet(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final library = context.read(libraryProvider.notifier);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Export library'),
              subtitle: const Text('Save your likes & playlists as .json'),
              onTap: () => Navigator.pop(ctx, 'export'),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Import library'),
              subtitle: const Text('Restore from a Gokenfy .json backup'),
              onTap: () => Navigator.pop(ctx, 'import'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == 'import') {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;
      final file = File(path);
      if (!await file.exists()) return;
      final text = await file.readAsString();
      final count = (jsonDecode(text)['likedSongs'] as List? ?? []).length;
      if (!context.mounted) return;
      final ok = await _confirm(
        context,
        'Restore ${_playlistCount(text)} playlists and $count liked songs?',
      );
      if (ok) {
        await library.importLibrary(text);
        messenger.showSnackBar(
          const SnackBar(content: Text('Library restored')),
        );
      }
      return;
    }

    if (action == 'export') {
      final text = library.exportLibrary();
      final out = await FilePicker.platform.saveFile(
        dialogTitle: 'Save library backup',
        fileName:
            'gokenfy_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.any,
        bytes: utf8.encode(text),
      );
      if (out != null) {
        messenger.showSnackBar(SnackBar(content: Text('Backup saved to $out')));
      }
    }
  }

  int _playlistCount(String json) =>
      (jsonDecode(json)['playlists'] as List? ?? []).length;

  Future<void> _importSpotifyCsv(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final csv = utf8.decode(bytes, allowMalformed: true);

    final importer = ref.read(csvImporterProvider);
    final tracks = importer.parse(csv);
    if (tracks.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No tracks found in that file.')),
      );
      return;
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ImportProgressDialog(
        importer: importer,
        tracks: tracks,
        onDone: (songs) {
          Navigator.pop(dialogContext);
          _finishImport(context, ref, songs);
        },
      ),
    );
  }

  Future<void> _finishImport(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (songs.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No tracks could be matched.')),
      );
      return;
    }
    final now = DateTime.now();
    final name = 'Spotify import ${now.day}/${now.month}/${now.year}';
    await ref.read(libraryProvider.notifier).createPlaylist(name, songs: songs);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Imported ${songs.length} songs into "$name"')),
      );
    }
  }

  Future<bool> _confirm(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          message,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String valueLabel;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      ),
      trailing: Text(
        valueLabel,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Slider(
        value: value.clamp(0.0, 1.0),
        activeColor: AppColors.accent,
        inactiveColor: AppColors.divider,
        onChanged: onChanged,
      ),
    );
  }
}

class _SleepChip extends StatelessWidget {
  const _SleepChip({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: active ? AppColors.background : AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Non-dismissible dialog that matches CSV rows against YT Music search.
class _ImportProgressDialog extends StatefulWidget {
  const _ImportProgressDialog({
    required this.importer,
    required this.tracks,
    required this.onDone,
  });

  final SpotifyCsvImporter importer;
  final List<SpotifyTrack> tracks;
  final void Function(List<Song>) onDone;

  @override
  State<_ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<_ImportProgressDialog> {
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final songs = await widget.importer.import(
      widget.tracks,
      onProgress: (d, _) {
        if (mounted) setState(() => _done = d);
      },
    );
    if (mounted) widget.onDone(songs);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      content: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Matching $_done / ${widget.tracks.length} tracks…',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
