# Morrow Distribution Readiness Design

## Intent

Make Morrow suitable for distribution outside the developer’s Mac: produce a Developer ID-signed, notarized and stapled DMG, and provide a publicly accessible privacy notice without exposing the private app source.

## Goals

- Make the release build use Developer ID Application signing, hardened runtime and Apple notarization; staple and validate the accepted ticket on the DMG.
- Keep signing identities and notarization credentials out of source control. Fail clearly when required credentials are unavailable; retain an explicit local-development/ad-hoc build path.
- Host the existing privacy notice on a minimal, separate public GitHub Pages repository and link to it from Morrow’s README and privacy settings.
- Keep the Morrow source repository private.

## Non-goals

- Publishing the Morrow source, uploading a GitHub release, or adding Sparkle auto-updates.
- Completing notarization without the required Apple Developer ID certificate and notary credentials.

## Approaches considered

1. **Separate public GitHub Pages repository (selected).** Publish only the privacy notice and static page from a dedicated repository. This preserves the existing private source repository and avoids adding a hosting service.
2. **Make the Morrow repository public.** Simpler Pages setup, but it exposes source and conflicts with the existing private-repository decision.
3. **Use another public hosting provider.** Keeps the GitHub repository arrangement, but requires selecting and configuring a separate host without a project-specific need.

## Design

- Extend `build.sh` with distinct local and distribution paths. Distribution requires an explicit Developer ID identity and a `notarytool` keychain profile, signs with hardened runtime, creates the DMG, submits it for notarization, waits for acceptance, staples the ticket, and validates the result. Credentials are supplied through environment/configuration references and never written into tracked files. Missing credentials produce setup guidance instead of an ad-hoc distribution artifact.
- Keep local development builds possible through an explicit ad-hoc mode.
- Create a minimal static privacy site in a dedicated public repository, with the current `PRIVACY.md` as its policy source and a simple readable landing page. Configure automatic GitHub Pages deployment and link the canonical public URL from the private app’s README and Settings privacy pane.
- Update the distribution documentation with certificate and notary profile prerequisites and the commands to build, notarize, staple and verify the DMG.

## Constraints and assumptions

- The current Morrow repository remains private.
- This Mac currently reports zero valid code-signing identities. The user must install a Developer ID Application certificate and configure an Apple notarytool keychain profile before a signed, notarized DMG can be produced.
- The privacy site contains only the privacy notice and its hosting workflow; it does not mirror application source.
- Changes remain uncommitted unless the user requests a commit. Publishing the separate public privacy repository is explicitly requested.
