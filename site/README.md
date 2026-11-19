# Landing page

The Dock Finder marketing page: one static `index.html` (no build step) plus the app icon in three sizes, made from `ios/biker-app/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.

To preview it locally:

```bash
python3 -m http.server 8000 --directory site
```

Then open http://localhost:8000.

The two "Download on the App Store" buttons link to https://apps.apple.com/us/app/dock-finder/id6823327404, and the `apple-itunes-app` meta tag (app ID `6823327404`) shows Safari's Smart App Banner on iPhone.

## Hosting: Cloudflare Pages

**Live at https://getdockfinder.com** (also `www.getdockfinder.com`). It's the Cloudflare Pages project `dockfinder`, whose own address is https://dockfinder-3so.pages.dev: `dockfinder.pages.dev` was taken, so Cloudflare added the `-3so` suffix.

It's already set up: root directory `site`, no build command, production branch `main`, build watch paths `site/*`. Branch pushes that touch `site/` get their own preview link. The steps below are for reference, or for setting it up again from scratch.

Cloudflare Pages deploys this folder straight from the GitHub repo through its own GitHub app, so there's no GitHub Actions workflow for the site. It keeps working if the repo goes private.

One-time setup, in the Cloudflare dashboard:

1. **Workers & Pages → Create → Pages → Connect to Git**, and authorize the Cloudflare GitHub app for the `dock-finder` org (only this repo is enough).
2. Pick `citibike-smart-dock-assistant`, with production branch `main`.
3. Build settings:
   - **Framework preset:** None
   - **Build command:** leave empty
   - **Build output directory:** `.`
   - **Root directory (advanced):** `site`
4. Save and deploy. The site goes live at `<project-name>.pages.dev`.
5. In the project's **Settings → Build → Build watch paths**, set **Include paths** to `site/*`. Pushes that don't touch `site/` then skip the deploy.
6. Optional: in **Settings → Builds → Branch control**, turn off preview deployments for branches other than `main`. Leaving them on gives every branch push its own preview link, which is useful for checking page changes before merging.

### Custom domain

`getdockfinder.com` is registered through Cloudflare Registrar in the same Cloudflare account, renewing automatically each year (next renewal Nov 19, 2027). Its DNS is on Cloudflare, and both `getdockfinder.com` and `www.getdockfinder.com` are custom domains on the Pages project, each a proxied CNAME to `dockfinder-3so.pages.dev`. Cloudflare issues and renews the HTTPS certificates.

To add another domain: **Custom domains → Set up a custom domain** on the Pages project. Custom domains and HTTPS are free; you only pay for the domain name.

- A subdomain such as `www.example.app` works with DNS anywhere: add the CNAME record Cloudflare shows.
- A bare domain such as `example.app` needs its DNS on Cloudflare: automatic if bought through Cloudflare Registrar, otherwise switch the domain's nameservers to Cloudflare (free).

## Keeping site changes out of App Store builds

App Store builds come from **Xcode Cloud** (the "Dock Finder | Default | Archive - iOS" check), not from GitHub Actions, so it needs its own start condition:

1. In Xcode, open the **Report navigator → Cloud**, right-click the **Default** workflow and choose **Edit Workflow…** (or App Store Connect → the app → **Xcode Cloud → Manage Workflows**).
2. Under **Start Conditions**, select the **Branch Changes** condition for `main`.
3. Under **Files and Folders**, choose **Don't start a build if only selected files and folders change**, and add `site` and `.github`.
4. Save.

Pushes that touch only `site/` or GitHub workflow files then skip the archive; a push that also touches `ios/` still builds. Set this up before merging a PR that changes only those folders, or that merge starts an archive.

The repo's GitHub Actions workflow, `shortcut-docs.yml`, also ignores pushes that only touch `site/`.

### Why not `[ci skip]`?

Xcode Cloud, GitHub Actions and Cloudflare Pages all skip a push whose commit message contains `[ci skip]` (or `[skip ci]`). That skips **all three**, including the site deploy, so it's the wrong tool for landing-page changes. It also only looks at the newest commit of a push: after a PR merge that's the merge commit ("Merge pull request #…"), so a `[ci skip]` in the branch's own commits has no effect unless you put it in the merge or squash commit message. Use it only when you deliberately want nothing to build, such as a README typo.
