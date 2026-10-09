import '../config/config.dart';

/// Maximum length of Community post text for the selected backend contract.
///
/// The disabled rollout uses the existing backend's 1000-character limit.
/// Enable 2200 characters together with multi-media only after backend #79 is
/// deployed. Both contracts count Unicode code points.
const int kCommunityPostMaxCharacters =
    AppConfig.enableCommunityMultiMedia ? 2200 : 1000;

/// Number of code points in [text], the same policy as the backend.
int communityPostCharacterCount(String text) => text.runes.length;

/// Whether [text], trimmed the way the backend trims it, is over the limit.
bool communityPostExceedsLimit(String text) =>
    communityPostCharacterCount(text.trim()) > kCommunityPostMaxCharacters;
