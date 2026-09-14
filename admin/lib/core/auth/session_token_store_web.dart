import 'package:web/web.dart' as web;

/// Web backing store for the "keep me signed in = off" case.
///
/// `sessionStorage` survives a page refresh within the same tab (so an
/// admin isn't kicked out mid-task by an F5) but is discarded when the tab
/// or window closes — exactly what an unchecked "keep me signed in" means
/// to a web user. Every access is guarded because browsers can throw on
/// storage access in some contexts (privacy modes, disabled site data).
String? readSessionValue(String key) {
  try {
    return web.window.sessionStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void writeSessionValue(String key, String value) {
  try {
    web.window.sessionStorage.setItem(key, value);
  } catch (_) {
    // Nothing durable to fall back to; the caller's in-memory claims still
    // drive the UI for this page load.
  }
}

void removeSessionValue(String key) {
  try {
    web.window.sessionStorage.removeItem(key);
  } catch (_) {
    // Already unreadable, so effectively gone.
  }
}
