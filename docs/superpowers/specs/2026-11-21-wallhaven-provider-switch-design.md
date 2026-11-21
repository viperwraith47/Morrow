# Wallhaven and Pixabay Provider Switch Design

## Intent

Add Wallhaven as a public, SFW wallpaper discovery provider and let users explicitly switch between Wallhaven and Pixabay in Settings. This replaces the existing key-driven Pixabay/Commons discovery fallback: a missing Pixabay key must be explained, never silently switch the selected source. Existing Commons library records remain usable.

## Goals

- Provide a persistent two-option Photo Source selector for Wallhaven and Pixabay.
- Search Wallhaven's public API without a key, explicitly restricting results to SFW.
- Require a saved Pixabay key for Pixabay searches. If it is missing, keep Pixabay selected, show a clear key-required message, and do not send a request or switch providers.
- Map Wallhaven's returned image URL, dimensions, file size, timestamp, thumbnail, and source page into the existing wallpaper model where available.
- Preserve existing Commons favorites, offline copies, collections, and attribution when viewing them.
- Update in-app source/privacy descriptions and the README, privacy notice, and project landing page to describe explicit provider selection and direct requests.

## Non-goals and anti-goals

- No Wallhaven key, account settings, NSFW/sketchy content, proxy server, or API-key storage.
- No Commons discovery option in the new selector; Commons remains supported for already-saved content only.
- Do not delete, rewrite, or silently migrate saved Commons records or files.
- Never silently fall back to another source when a selected provider cannot be used or returns an error.
- Do not claim Wallhaven images have a blanket reuse license. Link to the Wallhaven page and state that rights remain with their owners.

## Approaches considered

1. **Explicit Wallhaven/Pixabay choice (recommended).** Persist the selected source independently of key state. Wallhaven works without a key; Pixabay remains selected but displays a key-required message until a key is saved. This matches the requested two-source switch and avoids hidden behavior.
2. **Keep Commons as a third discovery option.** This retains all previous discovery choices, but expands the requested two-way switch and adds another ongoing settings state. Existing Commons library items do not require Commons to remain a discovery provider.
3. **Keep key-driven Commons fallback.** Rejected because it silently changes sources when Pixabay is selected without a key, contrary to the requested behavior.

## Design

- Add Wallhaven to the provider model while retaining Wikimedia Commons for decoding and displaying existing saved data.
- Store the selected discovery provider in `UserDefaults`, independent of Pixabay key presence. On upgrade, preserve Pixabay as the initial selection for installations with a saved Pixabay key; otherwise initialize to Wallhaven, the available no-key discovery source. Thereafter, restore the user's explicit selection.
- Add a Wallhaven service for `https://wallhaven.cc/api/v1/search`. Send `categories=100` (General only, excluding Anime and People) and `purity=100` (SFW only), use the API's 24-result pagination, pass the current search text through `q`, and keep the existing client-side orientation filter. An empty query uses Wallhaven's latest matching results. Use the returned `path` for the applicable image and the `thumbs` URL for tiles; validate remote URLs as HTTPS. Handle HTTP failures and 429 without changing the provider.
- Map Wallhaven `dimension_x`, `dimension_y`, `file_size`, and `created_at` into the existing metadata fields. Use its wallpaper page URL for attribution. The search response does not provide uploader identity, so do not invent one. Explain in provider credit text that image rights remain with their respective owners and refer users to the source page.
- Route discovery requests according to the persisted provider. When Pixabay is selected without a key, keep it selected, leave the results empty, and show a message directing the user to enter a key in Settings. Saving a key refreshes the current discovery query. API errors never trigger cross-provider fallback.
- Update Settings, credits, and the privacy/product documentation. Commons source attribution and metadata presentation continue to work for saved Commons records.

## Constraints and implementation calls

- Follow the existing SwiftUI/macOS 14 project structure and use native `URLSession`; add no dependency or server.
- Wallhaven's documented API is direct GET, supports category bitmasks (`100` for General only), defaults to latest SFW search, returns 24 items per page, and limits requests to 45 per minute. Keep requests paginated and present rate-limit errors clearly.
- The Pixabay key remains in macOS Keychain and is sent only to Pixabay. Wallhaven receives search terms and standard connection information, but no key.
- No new user decision is required. Defaulting an upgraded no-key installation to Wallhaven is the implementation call that replaces its former Commons fallback while giving it a working source immediately.

## Validation

- Build Debug and Release configurations.
- Exercise source switching, Pixabay-without-key messaging and no-fallback behavior, Wallhaven SFW search and pagination, and confirm existing Commons favorites/offline records still decode and display.
- Review all source/privacy copy for accurate key, licensing, and network disclosures.

## Reference

Wallhaven API v1 documentation supplied for this feature: https://wallhaven.cc/help/api
