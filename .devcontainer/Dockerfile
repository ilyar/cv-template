FROM mcr.microsoft.com/devcontainers/base:bookworm

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        fontconfig \
        inkscape \
        fonts-jetbrains-mono \
        make \
        poppler-utils \
        texlive-fonts-recommended \
        texlive-latex-base \
        texlive-latex-extra \
        texlive-latex-recommended \
        texlive-luatex \
        texlive-pictures \
    && fc-cache -f \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER vscode
