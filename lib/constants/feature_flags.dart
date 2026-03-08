/// Compile-time feature flags.
///
/// Flip these to `true` to enable in-development features without touching
/// any logic files. For a production remote-config approach these would be
/// sourced from the planet's API at runtime; for now a static const is
/// sufficient to keep the gate in one place.
library feature_flags;

/// Show a fade + scale-in entrance animation on [_MilestoneBanner] when a
/// guild milestone notification is present in the profile guild snapshot.
///
/// Set to `false` to render the banner statically (no animation).
const bool kMilestoneAnimationsEnabled = true;
