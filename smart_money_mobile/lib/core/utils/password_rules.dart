/// Matches the backend's special-character rule (`!char.IsLetterOrDigit`):
/// any character that is not a Unicode letter or decimal digit counts.
bool hasSpecialCharacter(String password) {
  return RegExp(r'[^\p{L}\p{Nd}]', unicode: true).hasMatch(password);
}
