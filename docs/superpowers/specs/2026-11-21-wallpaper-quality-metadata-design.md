# Wallpaper Quality and Source Metadata Design

## Intent

Help someone choose whether a wallpaper will look sharp enough when applied as a desktop background, while making image size and upload-date availability clear in the existing preview.

## Goals

- Label the highest-resolution rendition Morrow can actually download and apply: 4K, Full HD, HD, or Standard, based on its pixel dimensions.
- Show that rendition's dimensions; when different, also show the original source dimensions.
- Show the source file size when the provider supplies it, labeled as original/source size so it is not confused with a smaller available rendition.
- Show Commons' uploaded-version timestamp. Pixabay's documented API does not provide an upload date, so say that it is unavailable from Pixabay rather than inventing one.
- Keep existing saved favorites and offline records decodable when new optional metadata is absent.

## Non-goals

- No display-specific fit calculation, image enhancement, new API calls, migration of saved records, or change to which image URL is used to apply a wallpaper.
- No claim that source dimensions imply a particular visual quality beyond pixel resolution.

## Approaches

1. Label the source image only. Simple, but may claim 4K even when Morrow can only apply a smaller rendition.
2. Label the highest-resolution rendition Morrow can apply and show source dimensions separately when they differ. **Selected by the user:** this reflects the actual wallpaper output while preserving the source's full-resolution information.
3. Show only current model dimensions. This is smallest, but Pixabay's current model stores web-format dimensions even when Morrow selects a larger URL, so it can mislabel the applied rendition.

## Design

Place a compact, full-width metadata group in the wallpaper preview immediately after the title/action row and before offline/collection controls. This keeps the metadata readable at the preview's minimum window size. Example:

```text
[Full HD]  Available: 1920 × 1080 px
           Original: 4000 × 2250 px · 4.5 MB
           Uploaded: 27 Jun 2012
```

For Pixabay, omit the original line when it matches the available size and show `Upload date: Not provided by Pixabay`. For Commons, source and available dimensions are the same; display its current-version upload timestamp when present. Use system text styles and semantic colors, with the quality label conveyed by text rather than color alone.

Quality thresholds use the short and long dimensions, in either orientation: 4K at 3840 × 2160 or larger; Full HD at 1920 × 1080 or larger; HD at 1280 × 720 or larger; otherwise Standard. Display exact dimensions alongside the label so people can judge unusual aspect ratios themselves.

## Data and compatibility

- Add optional source dimensions, source byte size, and upload timestamp to `WallpaperPhoto`; preserve existing `width`/`height` as the best available rendition dimensions.
- Decode missing optional metadata as `nil`, preserving old favorites/offline catalog JSON and Commons identifiers. Legacy Pixabay records must not be mislabeled from their stored web-format dimensions; show their available resolution as unknown unless its exact rendition dimensions are known.
- For Pixabay, use `imageWidth`, `imageHeight`, and `imageSize` for source metadata. Derive available dimensions from the actual URL selected by the existing precedence: original (`imageURL`), Full HD (1920 max edge), large (1280 max edge), or web format (use its returned dimensions).
- For Commons, request/decode imageinfo timestamp and byte size alongside its existing exact original dimensions.
- Do not change provider routing, request frequency, caching, or image-download behavior.

## Verification

Build Debug and Release. Check resolution categories for landscape and portrait examples, the Pixabay original-versus-available difference, missing optional metadata in legacy saved JSON, Commons timestamps, and Pixabay's unavailable-date display. Confirm the UI still fits the resizable preview and uses no color-only status cue.

## Assumptions

`imageSize` from Pixabay and `size` from Commons refer to the original source file; they will be labeled accordingly. The Commons timestamp is the upload timestamp for the current file version, not necessarily the first time that image ever appeared on Commons.
