#!/usr/bin/env bash
# Builds build/cosmoskyfix-<version>.jar with plain javac. Needs JDK 21 and curl.
# Compile-only dependencies are downloaded once into .deps/ and checked against pinned SHA-256s.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-$(cat VERSION)}"
DEPS=.deps
OUT=build

deps=(
  "sponge-mixin.jar|https://maven.fabricmc.net/net/fabricmc/sponge-mixin/0.15.2%2Bmixin.0.8.7/sponge-mixin-0.15.2%2Bmixin.0.8.7.jar|1d45cfe3ae4a2eab38dc74276803748cf799088986260d6d912e50ddb35d15c5"
  "fml-loader.jar|https://maven.neoforged.net/releases/net/neoforged/fancymodloader/loader/4.0.45/loader-4.0.45.jar|8390398e67df23e72d85ed809685be2752c8ec545b7cbb6ad4b70fdc81e4dcd4"
  "mergetool-api.jar|https://maven.neoforged.net/releases/net/neoforged/mergetool/2.0.0/mergetool-2.0.0-api.jar|0260881294d8b218afe3d673f084d3745a55c28b35205d07d5e62d7f22202a00"
)

mkdir -p "$DEPS"
cp=()
for dep in "${deps[@]}"; do
  IFS='|' read -r name url sha <<<"$dep"
  if [[ ! -f "$DEPS/$name" ]]; then
    echo "Downloading $name"
    curl -fsSL "$url" -o "$DEPS/$name"
  fi
  echo "$sha  $DEPS/$name" | sha256sum -c --quiet -
  cp+=("$DEPS/$name")
done

rm -rf "$OUT"
mkdir -p "$OUT/stubs" "$OUT/classes"

javac --release 21 -d "$OUT/stubs" $(find stubs -name '*.java')
javac --release 21 -proc:none -Xlint:-options \
  -cp "$(IFS=:; echo "${cp[*]}"):$OUT/stubs" \
  -d "$OUT/classes" $(find src/main/java -name '*.java')

cp -r src/main/resources/. "$OUT/classes/"
sed -i "s/\${version}/$VERSION/" "$OUT/classes/META-INF/neoforge.mods.toml"

jar --create --file "$OUT/cosmoskyfix-$VERSION.jar" -C "$OUT/classes" .
echo "Built $OUT/cosmoskyfix-$VERSION.jar"
