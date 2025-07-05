#!/usr/bin/env bash

set -e

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <project_name> <subproject_name>"
  echo "Example: $0 myproject mylib"
  exit 1
fi

PROJECT_NAME="$1"
SUBPROJECT_NAME="$2"

PROJECT_NAME_UPPER=$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]')
SUBPROJECT_NAME_UPPER=$(echo "$SUBPROJECT_NAME" | tr '[:lower:]' '[:upper:]')

TEMPLATE_PROJECT_NAME="CHANGE_ME"
TEMPLATE_SUBPROJECT_NAME="example"

MAKEFILE="Makefile"
FLAKEFILE="flake.nix"

if [ ! -f "$MAKEFILE" ]; then
  echo "Error: $MAKEFILE not found!"
  exit 1
fi

if [ ! -f "$FLAKEFILE" ]; then
  echo "Error: $FLAKEFILE not found!"
  exit 1
fi

# 1. Update Makefile and flake.nix
sed -i \
  -e "s/$TEMPLATE_PROJECT_NAME/$PROJECT_NAME/g" \
  -e "s/\$(shell echo \$(PROJECT_NAME) | tr '\[:lower:\]' '\[:upper:\]')/$PROJECT_NAME_UPPER/g" \
  "$MAKEFILE"

sed -i \
  -e "s/\<$TEMPLATE_SUBPROJECT_NAME\>/$SUBPROJECT_NAME/g" \
  -e "s/\<${TEMPLATE_SUBPROJECT_NAME^^}\>/$SUBPROJECT_NAME_UPPER/g" \
  "$MAKEFILE"

sed -i \
  -e "s/$TEMPLATE_PROJECT_NAME/$PROJECT_NAME/g" \
  -e "s/package_name = \".*\";/package_name = \"$PROJECT_NAME\";/g" \
  -e "s/description = \".*\";/description = \"$PROJECT_NAME\";/g" \
  "$FLAKEFILE"

# 2. Create new subproject directories if they don't exist
mkdir -p "./$SUBPROJECT_NAME"
mkdir -p "./include/$SUBPROJECT_NAME"

# 3. Move and rename files from ./example to new subproject directory
if [ -d "./$TEMPLATE_SUBPROJECT_NAME" ]; then
  for f in ./$TEMPLATE_SUBPROJECT_NAME/*; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    newbase="${base//$TEMPLATE_PROJECT_NAME/$PROJECT_NAME}"
    newbase="${newbase//$TEMPLATE_SUBPROJECT_NAME/$SUBPROJECT_NAME}"
    mv "$f" "./$SUBPROJECT_NAME/$newbase"
  done
fi

# 4. Move and rename files from ./include/example to new include subproject directory
if [ -d "./include/$TEMPLATE_SUBPROJECT_NAME" ]; then
  for f in ./include/$TEMPLATE_SUBPROJECT_NAME/*; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    newbase="${base//$TEMPLATE_PROJECT_NAME/$PROJECT_NAME}"
    newbase="${newbase//$TEMPLATE_SUBPROJECT_NAME/$SUBPROJECT_NAME}"
    mv "$f" "./include/$SUBPROJECT_NAME/$newbase"
  done
fi

# 5. Remove old directories if empty (and from git, if present)
[ -d "./$TEMPLATE_SUBPROJECT_NAME" ] && rm -rf "./$TEMPLATE_SUBPROJECT_NAME"
[ -d "./include/$TEMPLATE_SUBPROJECT_NAME" ] && rm -rf "./include/$TEMPLATE_SUBPROJECT_NAME"

# 6. Update file contents in new locations
find "./$SUBPROJECT_NAME" "./include/$SUBPROJECT_NAME" -type f \( -name "*.c" -o -name "*.h" \) | while read -r file; do
  sed -i \
    -e "s/$TEMPLATE_PROJECT_NAME/$PROJECT_NAME/g" \
    -e "s/$TEMPLATE_SUBPROJECT_NAME/$SUBPROJECT_NAME/g" \
    -e "s/${TEMPLATE_PROJECT_NAME^^}/$PROJECT_NAME_UPPER/g" \
    -e "s/${TEMPLATE_SUBPROJECT_NAME^^}/$SUBPROJECT_NAME_UPPER/g" \
    "$file"
done

# 7. Remove the bootstrap script itself
SCRIPT_PATH="$(realpath "$0")"
BOOTSTRAP_BASENAME="$(basename "$SCRIPT_PATH")"
rm -f "$SCRIPT_PATH"

# 8. Rename the top level folder (where bootstrap.sh was called from) to the new project name if needed
STARTING_DIR="$(pwd)"
PARENT_DIR="$(dirname "$STARTING_DIR")"
CURRENT_BASENAME="$(basename "$STARTING_DIR")"
if [ "$CURRENT_BASENAME" != "$PROJECT_NAME" ]; then
  cd "$PARENT_DIR"
  mv "$CURRENT_BASENAME" "$PROJECT_NAME"
  cd "$PROJECT_NAME"
fi

# 9. Remove all git history and re-init, then create the first commit
if [ -d ".git" ]; then
  rm -rf .git
fi
git init
git checkout -b main # No gods, no masters
git add .
git commit -m "feat(${PROJECT_NAME}): initialized ${SUBPROJECT_NAME}"

echo "Done! All files and directories renamed, updated, old template files removed, top-level directory renamed, git history reset, and initial commit created."
