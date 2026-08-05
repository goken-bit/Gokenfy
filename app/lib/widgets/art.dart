import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A rounded square tile used for album/song art.
class ArtTile extends StatelessWidget {
  const ArtTile({super.key, this.radius = 10, this.size, this.seed = 0});

  final double radius;
  final double? size;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final s = size ?? 120.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(gradient: ArtGradients.of(seed)),
        child: Center(
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white.withValues(alpha: 0.55),
            size: s * 0.35,
          ),
        ),
      ),
    );
  }
}

/// Artwork that shows a remote image and falls back to a gradient tile.
class ArtImage extends StatelessWidget {
  const ArtImage({
    super.key,
    this.url,
    this.size = 120,
    this.radius = 10,
    this.seed = 0,
  });

  final String? url;
  final double size;
  final double radius;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final resolved = url == null || url!.isEmpty ? null : url;
    if (resolved == null) {
      return ArtTile(size: size, radius: radius, seed: seed);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => ArtTile(size: size, radius: 0, seed: seed),
        errorWidget: (_, __, ___) => ArtTile(size: size, radius: 0, seed: seed),
      ),
    );
  }
}

/// Horizontal-scrolling row of tiles (song/album cards) with an optional subtitle.
class TileRow extends StatelessWidget {
  const TileRow({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.width = 140,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: width + 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// Single card: square art on top, two lines of text below.
class ArtCard extends StatelessWidget {
  const ArtCard({
    super.key,
    required this.seed,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.width = 140,
    this.onTap,
  });

  final int seed;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtImage(
              url: imageUrl,
              size: width,
              radius: 10,
              seed: seed,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
