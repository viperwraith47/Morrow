---
name: github-showcase-readme
description: Write or refresh a project's GitHub README in a polished, visual, feature-rich showcase style. Use when a user asks for a README like a provided example, wants the README to explain the product in more detail, or asks for a strong GitHub landing page.
---

# GitHub Showcase README

Create a README that makes a project easy to understand, appealing to browse, and straightforward to build or use. The style is inspired by polished indie-app READMEs: a strong product title, optional icon and badges, a clear opening pitch, emoji-led feature highlights, a concise explanation of how the product works, and practical build, privacy, distribution, and credit details where relevant.

The reference is a style guide, not a source of facts. Keep every claim specific to the project being documented.

## Workflow

1. **Inspect before writing.** Read the current README and relevant source, project configuration, build scripts, assets, privacy and license files, and release configuration. Use the actual project as the source of truth for features, requirements, paths, commands, and limitations.
2. **Identify the audience and product promise.** Lead with what the project does, who benefits, and what distinguishes it. Use direct language; avoid generic praise such as “revolutionary” or “best-in-class” unless the user explicitly wants that voice.
3. **Choose sections that fit.** Keep the README focused on this project. A useful menu is below; include only sections that add real value.
4. **Write for GitHub.** Use standard Markdown. A small amount of HTML is fine for a centered icon or badges. Keep headings scannable and commands copyable.
5. **Fact-check the finished copy.** Verify each feature and technical claim against the source. Confirm referenced images, links, files, and commands exist. Remove claims that cannot be supported.

## Recommended shape

Use this as a flexible outline, not a required checklist:

```markdown
# [Relevant emoji] Product — short platform or purpose descriptor

[Centered product icon, if a suitable checked-in asset exists]

[Verified platform / language / framework badges, if useful]

[One or two paragraphs: what it is, what users can do, and its main differentiator.]

---

## ✨ Features

- **[Emoji] Feature:** Explain the user benefit and the important behavior.

---

## 🛠️ How It Works

[Short explanation and, when it clarifies a real flow, a small ASCII diagram.]

### Under the hood

[Source-grounded implementation details, only as technical as the audience needs.]

---

## 🚀 Build and Run

[Prerequisites, exact commands, outputs, and install or launch instructions.]

### Sharing the app

[Signing, notarization, permissions, and platform caveats, if relevant.]

---

## 🔐 Privacy and Licensing

[Data flows, local storage, third-party services, content rights, and limitations.]

---

## 🤝 Credits

[Verified contributors and upstream sources.]
```

## Style rules

- Use a distinctive title that names the product and explains its purpose or platform at a glance.
- If the repository has a suitable app icon or logo, show it near the top using its real repository-relative path. Do not invent screenshots or add external assets just for decoration.
- Add only useful, verifiable badges. Do not imply a release, license, build status, supported OS version, or language version that the repository does not establish.
- Make feature bullets concrete and user-centered. Prefer “Keep full-resolution originals for offline preview and applying” to generic claims such as “Offline support.”
- Use a few relevant emoji in section headings and feature bullets to create the lively showcase tone. Do not let emoji replace clear feature names or overwhelm the page.
- Add a flow diagram when the product has a meaningful pipeline, such as user input → service → validation → UI or local output. Keep it accurate and readable in a plain-text code fence.
- Include technical implementation names only when confirmed by code or project configuration. Explain why they matter; do not turn the README into an unverified architecture boast.
- Document exact build commands and outputs from the real build script. State prerequisites and important platform or signing caveats plainly.
- Explain privacy in concrete terms: what leaves the device, which services receive it, and what is stored locally. Never claim “no tracking,” “private,” or “offline” without checking how the app behaves.
- For content catalogs, APIs, or user-generated media, describe attribution and licensing carefully. Upstream metadata is not a legal guarantee unless the project's policy actually says so.
- Do not advise users to disable security protections or run blanket quarantine-removal commands. Prefer Developer ID signing and notarization for distribution; describe any local exception only when accurate and necessary.
- Include credits and links only when verified. Do not add a license badge or claim when the repository has no applicable license.
- Keep upgrade notes, troubleshooting, and limitations when they answer likely user questions; omit unrelated implementation history.

## Final review

Before finishing, check that:

- The opening clearly explains the product without requiring the reader to inspect source code.
- Feature descriptions match actual behavior, including meaningful constraints and side effects.
- Code blocks, filenames, image paths, links, badges, and build outputs are valid for this repository.
- Privacy, permissions, licensing, and distribution statements are honest and appropriately qualified.
- The README is fuller and more visual than a bare project summary, while remaining easy to scan.
