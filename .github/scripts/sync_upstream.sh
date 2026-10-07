#!/usr/bin/env bash
# Merge upstream without discarding fork changes, then decide whether a release is needed.
set -euo pipefail

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git fetch --no-tags https://github.com/xmrig/xmrig.git refs/heads/master
upstream_sha=$(git rev-parse FETCH_HEAD)
git merge --no-edit "$upstream_sha"
python3 .github/scripts/zero_donation.py
git add src/donate.h src/config.json src/core/config/Config_default.h src/core/config/usage.h
if ! git diff --cached --quiet; then
    git commit -m 'Set default and minimum donation levels to zero'
fi
# A regular push fails safely if the branch moved or branch protection blocks updates.
git push origin "HEAD:refs/heads/$DEFAULT_BRANCH"
source_sha=$(git rev-parse HEAD)
tag="build-${upstream_sha:0:12}-${source_sha:0:12}"

# Inspect all releases, including drafts; API/network failures must not look like a missing release.
releases=$(gh api --paginate "repos/$GITHUB_REPOSITORY/releases?per_page=100" --jq '.[] | {tag_name, draft, assets: [.assets[].name]}')
complete=$(printf '%s\n' "$releases" | jq -s --arg tag "$tag" '
    any(.[]; .tag_name == $tag and .draft == false and
        (([.assets[] | select(test("^xmrig-(windows-x86-64-v3\\.zip|linux-x86-64-v3\\.tar\\.gz|macos-arm64\\.tar\\.gz)$"))] | length) == 3) and
        (.assets | index("SHA256SUMS") != null))')
build=true
if [[ "$complete" == true ]]; then
    build=false
fi
{
    echo "build=$build"
    echo "source_sha=$source_sha"
    echo "upstream_sha=$upstream_sha"
    echo "tag=$tag"
} >> "$GITHUB_OUTPUT"
