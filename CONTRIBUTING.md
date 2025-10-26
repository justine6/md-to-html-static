# Contributing Guide

Thanks for contributing to **Jutellane Blog — md-to-html-static**!  
This project builds a sanitized, fast static site from Markdown and deploys to:
- GitHub Pages (this repo), and
- `justine6/jutellane-blogs` (main site).

## Quick Start

1. **Fork & clone** the repo
2. **Create a branch**: `git checkout -b feat/my-change`
3. **Install & build**:
   ```bash
   npm ci
   npm run build
   npm run serve   # local preview at http://127.0.0.1:3000
