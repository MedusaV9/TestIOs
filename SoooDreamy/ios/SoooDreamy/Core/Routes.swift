import Foundation

/// Push destinations of the Erinnerungen tab. Declared Foundation-only so the
/// search index (and its Linux unit tests) can target them; the views are
/// resolved in `MemoriesView.destination(for:)`.
enum MemoriesRoute: Hashable {
    case gallery, videos, canvas, bucket, events, stats, journal
    case coupons, soundtrack, lists, potd, vault, yearReview
    case capsules, goals, weekplan, magazine
}
