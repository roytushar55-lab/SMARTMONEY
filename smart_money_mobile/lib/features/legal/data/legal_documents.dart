/// The Terms of Service / Privacy Policy bundled with the app.
///
/// [consentVersion] is sent to the backend at signup so the stored consent
/// points at the exact text the user saw. Bump it whenever the files in
/// assets/legal/ change in a way users must re-accept.
class LegalDocuments {
  LegalDocuments._();

  static const consentVersion = '2026-10-05';

  static const terms = LegalDocument(
    title: 'Terms of Service',
    assetPath: 'assets/legal/terms_of_service.md',
  );

  static const privacy = LegalDocument(
    title: 'Privacy Policy',
    assetPath: 'assets/legal/privacy_policy.md',
  );

  /// Resolves a link target found inside a document (e.g.
  /// `PRIVACY_POLICY.md`) to a bundled document, or null if it is external.
  static LegalDocument? fromLink(String target) {
    switch (target) {
      case 'TERMS_OF_SERVICE.md':
        return terms;
      case 'PRIVACY_POLICY.md':
        return privacy;
      default:
        return null;
    }
  }
}

class LegalDocument {
  const LegalDocument({required this.title, required this.assetPath});

  final String title;
  final String assetPath;
}
