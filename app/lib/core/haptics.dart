import 'package:flutter/services.dart';

/// Light haptic tap feedback.
Future<void> hapticTap() => HapticFeedback.lightImpact();

/// Subtle selection click.
Future<void> hapticSelect() => HapticFeedback.selectionClick();

/// Medium impact (e.g. transport control toggles).
Future<void> hapticMedium() => HapticFeedback.mediumImpact();
