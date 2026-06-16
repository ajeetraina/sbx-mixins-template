#!/usr/bin/env bash
# Validate and push this mixin kit to a registry as one or more tags.
#
#   ./scripts/push-kit.sh                 # pushes :latest from the repo root spec
#   TAG=v1 ./scripts/push-kit.sh          # pushes :v1
#   DOCKERHUB_NAMESPACE=me ./scripts/push-kit.sh
#
# If you add provider/variant specs under kits/<variant>/spec.yaml, this also
# pushes each as its own tag (:<variant>), mirroring the sbx-kits-mem0 layout.
set -euo pipefail

namespace="${DOCKERHUB_NAMESPACE:-${DOCKER_NAMESPACE:-<your-namespace>}}"
kit_name="${KIT_NAME:-<kit-name>}"          # also the staged subdir name
tag="${TAG:-latest}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
image="docker.io/$namespace/$kit_name"

# publish SPEC_DIR IMAGE_TAG README_FILE
# Stages a kit (spec.yaml + README + LICENSE), validates it, and pushes one tag.
publish() {
  local spec_dir="$1" image_tag="$2" readme="$3"
  local stage
  stage="$(mktemp -d /tmp/sbx-kit-push.XXXXXX)"
  mkdir -p "$stage/$kit_name"
  cp "$spec_dir/spec.yaml" "$stage/$kit_name/spec.yaml"
  cp "$readme" "$stage/$kit_name/README.md"
  [ -f "$repo_root/LICENSE" ] && cp "$repo_root/LICENSE" "$stage/$kit_name/LICENSE"
  sbx kit validate "$stage/$kit_name"
  sbx kit push "$stage/$kit_name" "$image:$image_tag"
  rm -rf "$stage"
  echo "Pushed $image:$image_tag"
}

# Default kit at the repo root -> :$tag (default :latest).
publish "$repo_root" "$tag" "$repo_root/README.md"

# Optional per-variant kits under kits/<variant>/spec.yaml -> :<variant>.
if [ -d "$repo_root/kits" ]; then
  for dir in "$repo_root"/kits/*/; do
    [ -f "$dir/spec.yaml" ] || continue
    variant="$(basename "$dir")"
    readme="$repo_root/kits/$variant/README.md"
    [ -f "$readme" ] || readme="$repo_root/README.md"
    publish "$dir" "$variant" "$readme"
  done
fi
