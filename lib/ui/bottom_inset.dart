import 'package:flutter/material.dart';

/// Keeping a vertical scroll view clear of the system navigation bar.
///
/// Android 15 draws apps edge to edge, behind the gesture pill or the
/// three-button bar. Flutter pads a `ListView`/`GridView` against that by
/// itself, but only when its `padding` is null: the moment a screen writes
/// `padding: const EdgeInsets.all(16)`, the inset is dropped and the last row
/// sits under the nav bar with no way to scroll it out. A
/// `SingleChildScrollView` never applies the inset at all.
///
/// **The rule:** a vertical scroll view with an explicit `padding` adds the
/// inset back with [BottomInsetPadding.safeBottom]. Don't guess it with a
/// fixed `bottom: 32`, which is too small for a three-button bar.
///
/// It is always safe to add: a `Scaffold` with a `bottomNavigationBar` (the
/// home and staff shells) and a `SafeArea` remove the inset from the
/// MediaQuery below them, so there it resolves to zero.
///
/// Where the scroll view isn't what reaches the bottom of the window — a
/// dialog's content, a nested `shrinkWrap` list, a form whose enclosing
/// padding already clears the bar — say so in a `bottom-inset-ok:` comment
/// above it. test/bottom_inset_test.dart holds every scroll view to this.
extension BottomInsetContext on BuildContext {
  /// The system bottom inset, or zero where an ancestor already took it.
  double get bottomInset => MediaQuery.paddingOf(this).bottom;
}

extension BottomInsetPadding on EdgeInsets {
  /// This padding, plus the system bottom inset.
  EdgeInsets safeBottom(BuildContext context) => copyWith(bottom: bottom + context.bottomInset);
}
