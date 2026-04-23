#!/usr/bin/env bash
set -euo pipefail

# Usage:
# ./create_and_push_repo.sh /path/to/project repo-name [public|private]
# Example:
# ./create_and_push_repo.sh ~/projects/mmrec_project mmrec_project_demo public

PROJECT_DIR="${1:-}"
REPO_NAME="${2:-mmrec_project_demo}"
VISIBILITY="${3:-private}"  # public or private

if [[ -z "$PROJECT_DIR" ]]; then
  echo "Usage: $0 /path/to/project repo-name [public|private]"
  exit 1
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Project directory not found: $PROJECT_DIR"
  exit 2
fi

# Check dependencies
if ! command -v git >/dev/null 2>&1; then
  echo "git not found. Install git and retry."
  exit 3
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) not found. Install and run 'gh auth login' first."
  exit 4
fi

echo "Project: $PROJECT_DIR"
echo "Repo name: $REPO_NAME"
echo "Visibility: $VISIBILITY"

# Create temp working copy to avoid modifying original
TMPROOT="$(mktemp -d)"
TMPDIR="$TMPROOT/$REPO_NAME"
echo "Creating temporary copy at $TMPDIR"
cp -a "$PROJECT_DIR" "$TMPDIR"

# Remove common sensitive files if exist
echo "Cleaning common sensitive files (.env, .env.local, .secrets, *.key) from temp copy..."
find "$TMPDIR" -type f \( -name ".env" -o -name ".env.*" -o -name "*.env" -o -name "*.key" -o -name "*.pem" \) -print -exec rm -f {} \;

# Add .gitignore if not present
GITIGNORE="$TMPDIR/.gitignore"
if [[ ! -f "$GITIGNORE" ]]; then
  cat > "$GITIGNORE" <<'GITIGNORE'
# OS files
.DS_Store
Thumbs.db

# Python
__pycache__/
*.pyc
*.pyo
*.pyd
env/
venv/
.env

# Node
node_modules/
dist/
build/

# Data and large files (do NOT commit heavy posters unless using LFS)
data/
*.sqlite
*.db
frontend/public/static/posters/

# IDE
.vscode/
.idea/

GITIGNORE
  echo ".gitignore created"
else
  echo ".gitignore exists, leaving it"
fi

# Warn about posters (large)
POSTER_DIR="$TMPDIR/frontend/public/static/posters"
if [[ -d "$POSTER_DIR" ]]; then
  echo "Notice: posters directory exists at $POSTER_DIR"
  echo "It's recommended NOT to push large poster files to Git. Use Git LFS or keep posters offline and copy them into place after clone."
fi

# Create repository and push
echo "Initializing git repo in temp dir..."
cd "$TMPDIR"
git init
git add -A
git commit -m "Initial commit: MMRec project packaged for GitHub"

echo "Creating GitHub repo via 'gh'..."
# Use gh to create repo and push current directory
# --source . --remote=origin --push pushes current repo to remote
gh repo create "$REPO_NAME" --"$VISIBILITY" --source=. --remote=origin --push --confirm

echo "Repository created and pushed. Getting repo info..."
REPO_URL=$(gh repo view --json sshUrl, httpUrl -q '.httpUrl')
echo "Repository URL: $REPO_URL"

echo "Cleaning up temp files..."
# Optionally keep temp dir for debugging - we'll remove it
rm -rf "$TMPROOT"

echo "Done. You can now clone the repo in VSCode or by running:"
echo "git clone $REPO_URL"
echo "Then open in VSCode: code $REPO_NAME"