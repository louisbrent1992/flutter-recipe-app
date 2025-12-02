/// Formats a community user's display name for privacy:
/// - If name has multiple parts (first + last): returns "FirstName LastInitial."
/// - If name is single word: returns the name as-is
///
/// Examples:
/// - "John Smith" -> "John S."
/// - "Mary Jane Watson" -> "Mary W."
/// - "John" -> "John"
/// - "Madonna" -> "Madonna"
String formatCommunityUserName(String? displayName) {
  if (displayName == null || displayName.trim().isEmpty) {
    return 'Chef';
  }

  final trimmed = displayName.trim();
  final parts = trimmed.split(RegExp(r'\s+'));

  // If only one word, return as-is
  if (parts.length == 1) {
    return parts.first;
  }

  // If multiple words, use first name + last initial
  final firstName = parts.first;
  final lastInitial = parts.last.isNotEmpty ? parts.last[0].toUpperCase() : '';

  return '$firstName $lastInitial.';
}
