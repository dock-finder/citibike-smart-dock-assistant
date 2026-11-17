# Landing page

The Dock Finder marketing page: one static `index.html` (no build step) plus the app icon in three sizes, made from `ios/biker-app/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.

To preview it locally:

```bash
python3 -m http.server 8000 --directory site
```

Then open http://localhost:8000.

## Publishing

`.github/workflows/site.yml` deploys this folder to GitHub Pages whenever something under `site/` changes on `main`, at https://dock-finder.github.io/citibike-smart-dock-assistant/. It needs Pages turned on once: repo **Settings → Pages → Source: GitHub Actions**.

When the app is live, swap the two "Coming soon to the App Store" buttons in `index.html` for the App Store link (the comment above the first one says how).

## Keeping site changes out of App Store builds

App Store builds come from **Xcode Cloud** (the "Dock Finder | Default | Archive - iOS" check), not from GitHub Actions, so a GitHub workflow can't stop them. Xcode Cloud's own start condition does:

1. In Xcode, open the **Report navigator → Cloud**, right-click the **Default** workflow and choose **Edit Workflow…** (or App Store Connect → the app → **Xcode Cloud → Manage Workflows**).
2. Under **Start Conditions**, select the **Branch Changes** condition for `main`.
3. Under **Files and Folders**, choose **Don't start a build if only selected files and folders change**, and add `site`.
4. Save.

Pushes that touch only `site/` then skip the archive; a push that also touches `ios/` still builds. For a one-off skip, put `[ci skip]` in the commit message: Xcode Cloud honors it too.

The repo's other workflow, `shortcut-docs.yml`, also ignores pushes that only touch `site/`.
