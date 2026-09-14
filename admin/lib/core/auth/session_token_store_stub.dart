/// Non-web fallback for the "keep me signed in = off" token store.
///
/// Browsers have `sessionStorage`, which dies with the tab; native
/// platforms have no equivalent, so tokens simply live in process memory
/// and vanish when the app is killed. Same contract as the web file: the
/// conditional import in token_storage_service.dart requires identical
/// signatures.
final Map<String, String> _memory = <String, String>{};

String? readSessionValue(String key) => _memory[key];

void writeSessionValue(String key, String value) => _memory[key] = value;

void removeSessionValue(String key) => _memory.remove(key);
