# ARDC Vocabulary Service System Documentation

This repository contains system documentation for the ARDC Vocabulary
Service.

Content in this repository includes:

- High-level project information
- Documentation that cuts across more than one of the underlying
  projects (e.g., that relates to both the Portal and the Registry)
- Requirements
- Design
  - Database design documents
  - Software design documents
- Any other documents that don't (currently) fit well in one of the
  other related projects
- Tools and build configuration for generating documentation in
  convenient formats

# A note on document formats

In order to accommodate content that is reasonably complex, we are
using pandoc-flavoured Markdown. The main difference is in top-level
metadata, and support for complex tables.

In practice, that means that the usual content previews provided by
Bitbucket and GitHub don't display the content correctly. Files must
be processed by pandoc into HTML in order to see tables and other
content correctly.
