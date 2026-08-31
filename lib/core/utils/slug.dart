/// Converts heading text to a GitHub-style URL slug for anchor links.
/// e.g. "My Heading 1" → "my-heading-1"
///
/// Shared between the markdown renderer (which assigns these as heading
/// keys) and the merge-notes generators (which write matching `#slug`
/// links into the Agenda/Master Agenda) — both MUST use this exact
/// function so generated links always resolve to a real heading.
String toSlug(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '-');
}
