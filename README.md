# CV PDF Template

A minimal template for generating a CV PDF from a single Markdown file

## Goal

- edit `cv.md` adn optionally add `cv.png` or `cv.jpg` to override the generated identicon
- run `make pdf`
- get `cv-xp-<mode>.pdf`

## Local build

```bash
make doctor
make pdf xp=4       # show 4 full experience entries
make pdf xp=full    # show all experience entries in full format
```

## Dev Container CLI

Docker is required for this workflow

```bash
npm install -g @devcontainers/cli
devcontainer up
devcontainer exec make pdf
```

Or use [deco](https://github.com/ilyar/deco) alternatively for `@devcontainers/cli` 

```bash
curl -fsSL https://raw.githubusercontent.com/ilyar/deco/refs/heads/main/install.sh | bash
deco exec make pdf
```
