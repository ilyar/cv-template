# CV PDF Template

A minimal template for generating a CV PDF from a single Markdown file

## Goal

- edit `cv.md` if `cv.png` or `cv.jpg` exists in the project root, it is used, otherwise, an avatar is downloaded from the [DiceBear Identicon](http://dicebear.com/styles/identicon/)
- run `make pdf`
- get `cv-xp-<mode>.pdf`

## Local build

```bash
make doctor
make pdf xp=5       # show 5 full experience entries
make pdf xp=full    # show all experience entries in full format
```

## Dev Container CLI

Docker is required for this workflow

```bash
npm install -g @devcontainers/cli
devcontainer up
devcontainer exec make pdf
```
