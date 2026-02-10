Read and follow the guidelines in AGENTS.md before making any changes.

## Project-specific rules

- Update documentation in /docs after making changes to the codebase that are significant enough to document.
- Default locale is Polish (`pl`). All user-facing text must use Gettext.
- Registration is invitation-only. Never expose a public signup route.
- Never cast `platform_admin` in public-facing changesets.
- Always run `mix test` after changes and fix any failures before finishing.
- Always run `mix compile --warnings-as-errors` and fix all warnings.
