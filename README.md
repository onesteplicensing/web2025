# 🚀 One Step Licensing Jekyll (4.4.1) Website

This is a Jekyll-based static website built with modular includes, SCSS styling, and structured content in Markdown files. This guide explains the structure and how to maintain or modify different parts of the website.

---

## 📁 Project Structure Overview


---

## 🧩 Editing the Website Content

### 🔹 HTML Section Partials (`_includes/can-am/`)

This folder contains reusable HTML components included in layouts or pages.

| File Name        | Description                                  |
|------------------|----------------------------------------------|
| `about.html`     | About section content                        |
| `contact.html`   | Contact section (form, info)                 |
| `footer.html`    | Site footer                                  |
| `header.html`    | Navigation/header                            |
| `hero.html`      | Hero/landing section                         |
| `services.html`  | List of services                             |
| `showCase.html`  | Project or product showcase section          |
| `timeline.html`  | Timeline or process steps section            |
| `videoGames.html`| Section for listing video games              |

**To edit:** Open the corresponding HTML file inside `_includes/can-am/` and modify the HTML content.

### 🔹 Layouts (`_layouts/`)

Templates that wrap around pages or sections.

| File Name      | Used For                                       |
|----------------|------------------------------------------------|
| `default.html` | Base layout (includes header/footer)           |
| `home.html`    | Homepage-specific layout                       |
| `page.html`    | Standard page layout                           |

**To edit:** Update layout wrappers, include blocks, or surrounding structure.

---

## 📝 Markdown Pages (`pages/`)

These are individual content pages written in Markdown and rendered using layouts.

| File Name           | Purpose                                    |
|---------------------|--------------------------------------------|
| `can-am-details.md` | Details page about Can-Am products         |
| `can-am-games.md`   | Games-related content                      |
| `can-am-toys.md`    | Toys-related content                       |

Each page contains YAML front matter and Markdown content. Example:

```markdown
---
layout: page
title: Can-Am Details
---
## Product Highlights

This section describes Can-Am features and models...



## ⚙️ Jekyll Installation & Running Locally

### ✅ Prerequisites

Make sure you have the following installed:

- **Ruby** (v3.4.4 or higher) — check with:

  ```bash
  ruby -v
  ```

- **Bundler** — install it via:

  ```bash
  gem install bundler
  ```

> 💡 On **Windows**, it's recommended to use [RubyInstaller](https://rubyinstaller.org/) and enable the MSYS2 development toolchain during setup.

---

### 📦 Install Project Dependencies

From the root directory of the project, run:

```bash
bundle install
```

This installs Jekyll and all required gems defined in the `Gemfile`.

---

### 🚀 Run Jekyll Locally with Live Reload

To serve the site locally and enable automatic browser refresh on file changes:

```bash
bundle exec jekyll serve --livereload
```

Visit your local site at:

```
http://localhost:4000
```

or

```
http://127.0.0.1:4000/
```

Jekyll will watch for changes in HTML, Markdown, SCSS, and other files, and reload the browser automatically.

---

## 🐳 Run Jekyll Locally Using Docker

If you prefer not to install Ruby and Bundler directly, you can use Docker to run the Jekyll server in a container.

### ✅ Prerequisites

- [Docker](https://www.docker.com/get-started) installed on your system

### 📦 Using Docker Compose

A `docker-compose.yml` file is provided in the project. To start the Jekyll server:

1. Open a terminal and navigate to the project directory.
2. Start the Jekyll server using Docker Compose:

   ```bash
   docker-compose up
   ```

   Or run in detached mode:

   ```bash
   docker-compose up -d
   ```

3. Visit your local site at `http://localhost:4000`

The container will automatically watch for changes and rebuild the site as needed. All your files are mounted into the container, so edits on your host machine will be reflected in the running site.
