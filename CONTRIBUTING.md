# Contributing

Contributions, bug reports, and new TeXmacs test fixtures are very welcome!

## Development Workflow

1. Link the plugin into your local TeXmacs configuration:
   ```bash
   ./scripts/setup.sh
   ```
2. Make your changes under `plugin/progs/` or `plugin/packages/accessibility/`.
3. Validate against all fixtures (TeXmacs CLI export + `typst compile --pdf-standard a-2b,ua-1` + `veraPDF`):
   ```bash
   for f in tests/fixtures/*.tm; do
     ./scripts/test-pipeline.sh "$f"
   done
   ```
4. Check the generated `.typ` files in `tests/out/` for any `/* TODO-TAG: ... */` or `/* TODO-MATH: ... */` comments.

## Guidelines

- Verify TeXmacs Scheme APIs against the local TeXmacs installation (`/usr/share/TeXmacs/progs/convert/`) rather than guessing.
- Keep accessibility (PDF/UA-1 & WCAG) as a top priority: semantic headings, `table.header(...)`, image `alt` texts, `#pdf.artifact(...)` for decorative images, and document language/title metadata.
- Do not commit private documents or generated files in `tests/out/`.

## License

By contributing to this repository, you agree that your contributions will be licensed under the **GNU General Public License v2.0 or later** (see [LICENSE](LICENSE)).
