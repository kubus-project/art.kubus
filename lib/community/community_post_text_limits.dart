/// Canonical maximum length of Community post text, in Unicode code points.
///
/// Mirrors `COMMUNITY_POST_CONTENT_MAX_CHARACTERS` on the backend. Both sides
/// count code points, so accented Slovenian letters and emoji agree.
const int kCommunityPostMaxCharacters = 2200;

/// Number of code points in [text], the same policy as the backend.
int communityPostCharacterCount(String text) => text.runes.length;

/// Whether [text], trimmed the way the backend trims it, is over the limit.
bool communityPostExceedsLimit(String text) =>
    communityPostCharacterCount(text.trim()) > kCommunityPostMaxCharacters;
