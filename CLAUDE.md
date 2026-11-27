# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Jekyll 4.4 static site for OneStep Licensing (a brand licensing agent). No JS build step, tests or linters: "does it build cleanly and look right" is the check.

## Staging vs prod

- **This repo is staging:** `onesteplicensing/web2025` (`origin`), served at https://weathered-dust-1420.onesteplicensing.com.
- **Prod is a separate repo:** `onesteplicensing/web2023` (git remote `prod`), served at https://www.onesteplicensing.com.
- **Both sites publish from `gh-pages`, the only branch that matters here.** `main` is GitHub's default branch but stale (2024). `jek-v4` and `feat/jek-v4-with-data` hold unmerged 2025 work.
- **Changes flow staging → prod through a PR the user opens and merges themselves.**
  - Never open, merge or push anything to prod.
  - Those PRs are merged with "Create a merge commit", never squash. A squash merge breaks shared history and caused deleted files to come back in Nov 2025.
- **The user sometimes edits prod directly.** Before building on staging, bring those edits back with the `catchup-to-prod` skill (`.claude/skills/catchup-to-prod/`). It has safety checks for unpushed or uncommitted work and for files staging deliberately deleted.
- **Deploys run through GitHub Actions.** `.github/workflows/pages.yml` runs on every push to `gh-pages` and is identical in both repos.
  - Each repo's custom domain is set in its own Settings → Pages, not in a `CNAME` file.
  - Never copy a `CNAME` from one repo to the other.
- **`Gemfile.lock` must keep the `x86_64-linux` platform,** or the Actions build fails. It originally only had Windows.

## Commands

The system Ruby on the user's Mac is 2.6, too old (`.ruby-version` is 3.4.4), so run Jekyll in Docker. The `osl-bundle` volume caches installed gems between runs:

```bash
# build into _site/ (Actions builds with JEKYLL_ENV=production)
docker run --rm -v "$PWD:/srv" -v osl-bundle:/usr/local/bundle -w /srv ruby:3.4 \
  sh -c 'bundle install --quiet && bundle exec jekyll build'

# serve at http://localhost:4000
docker run --rm -it -p 4000:4000 -v "$PWD:/srv" -v osl-bundle:/usr/local/bundle -w /srv ruby:3.4 \
  sh -c 'bundle install --quiet && bundle exec jekyll serve --host 0.0.0.0 --livereload'
```

The README's `bundle exec jekyll serve --livereload` works only with a local Ruby 3.4.

**Viewing pages:** use the Playwright MCP server from `.mcp.json` (`@playwright/mcp --extension`, which drives the user's browser). Point it at the local server, the staging URL or the prod URL. To check a change, compare staging with prod or with local.

**One known build warning:** "Conflict … `/assets/css/style.css`". See CSS below.

## Architecture

Most content edits are YAML edits in `_data/`, not HTML.

- **Home page:** `index.markdown` → `_layouts/home.html` → `_layouts/default.html`.
  - `default.html` hard-codes the section order: header, hero, showCase, about, timeline, services, contact, footer.
  - Each `_includes/<section>.html` renders `site.data.<section>` from `_data/<section>.yml`.
- **Homepage showcase tiles:** `_data/showcase.yml`.
  - `page:` links a tile to a brand page.
  - Hide a tile by commenting out its entry. That's how Porsche is hidden.
- **Timeline:** `_data/timeline.yml`. Each year picks a `template:` (`timeline-template-1` … `-6`, documented at the top of the YAML).
  - The branches in `_includes/timeline.html` render each template.
  - The `content:` shape differs per template: a list of blocks for some, a single map for others.
  - The `active: true` entry is the year shown first.
- **Brand toy pages:** `pages/<brand>-toys.md` (layout `page`) calls `{% include showcase/toys.html toys_data=site.data.showcases.<brand>_toys toys_brand_name="<brand>" %}`.
  - Header, navigation, hero images and intro text come from `_data/showcases/<brand>_toys.yml`.
  - The toy cards come from the `toys` collection, filtered by front-matter `brand`.
  - The README has the full "Adding a New Toy Showcase Page" walkthrough.
- **Toys collection:** `_toys/<brand>/*.md`, using layout `toy_details`.
  - `brand` is required, or the toy won't appear on its brand page.
  - A front-matter `permalink` overrides the collection default `/toys/:name/`.
  - Two files with the same output path silently overwrite each other; Jekyll prints a "Conflict" warning.
- **CSS:** `assets/css/style.scss` imports the `_*.scss` partials.
  - **But** a committed, compiled `assets/css/style.css` (+ `.map`) writes to the same path and wins, so SCSS edits don't reach the site unless that file is regenerated or removed.
  - As of Nov 2026, the committed file predates the Sep 2025 timeline SCSS refactor.
- **JS:** plain scripts in `assets/js/` (Bootstrap bundle plus small per-feature files). Pages that need them load them directly, e.g. `toysGallery.js` on toy pages.
- **Images:** many are hosted on imgbb (`i.ibb.co`); the rest live in `assets/images/`. Source media is on the Google Drive linked in the README.
- **Stray files at the repo root get published:** files without front matter, such as `README.md`, `LICENSE.md`, `docker-compose.yml` and `run-script.txt`, are copied to the site as static files. Add anything that mustn't be public to `exclude:` in `_config.yml`.

## Guidelines
- make no assumptions, ask the user as many clarifying questions in multi-turn style as much as needed
- when provided with new asset (images) in github issue, let's use the github hosted image URL
