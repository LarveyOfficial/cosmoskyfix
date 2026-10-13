# Cosmonautics Sky Fix

A tiny client-side NeoForge mod that fixes a render-thread FPS drain in
[Create Cosmonautics](https://modrinth.com/mod/create-cosmonatics) (mod id `rocketnautics`) on Minecraft 1.21.1.

## The problem

Every game tick (20 times a second), Cosmonautics rebuilds a 64×64 "star plasma" noise
texture on the CPU, on the render thread, and re-uploads it to the GPU. Each rebuild runs
warped fractal noise for all 4,096 pixels. It does this whenever you're in a dimension it
treats as a planet (including the Overworld), even with `enableCustomSky = false` in its
config, because that setting doesn't gate this code path.

Profiling a modpack client on a Ryzen 9 5900X showed `SkyHandler$StarNoise.fbm` taking
about **7–22% of render thread time**, with no setting to turn it off. Since the render thread
was the bottleneck, that translated directly into lost FPS.

## The fix

A single mixin hooks the start of `SkyHandler.ensureStarPlasmaTexture()` and lets it run at most
once every 500 ms. Other calls return early and reuse the texture that's already uploaded.

- The first build always goes through, so the texture always exists.
- The plasma pattern still animates, in steps of 0.5 s instead of every tick.
- Measured result: the star texture went from 7–22% of render thread time to under 1%.

```java
@Inject(method = "ensureStarPlasmaTexture", at = @At("HEAD"), cancellable = true)
private static void cosmoskyfix$throttle(CallbackInfo ci) {
    long now = System.nanoTime();
    if (STAR_PLASMA_TEXTURE_ID != null && now - cosmoskyfix$lastRegen < cosmoskyfix$INTERVAL_NANOS) {
        ci.cancel();
        return;
    }
    cosmoskyfix$lastRegen = now;
}
```

### Safety

- **Client-side only.** Servers and other players don't need it. It adds no blocks, items or
  network traffic.
- **Won't crash on updates.** The mixin config is `"required": false` with `defaultRequire: 0`.
  If a future Cosmonautics release renames or removes this method, the mixin is skipped with a log
  warning instead of crashing the game.
- **Doesn't require Cosmonautics.** Without Cosmonautics installed it does nothing.

## Installation

1. Download the latest `cosmoskyfix-<version>.jar` from [Releases](../../releases).
2. Drop it into your instance's `mods/` folder, next to Cosmonautics.
3. Launch the game. `latest.log` should list `Cosmonautics Sky Fix` among the loaded mods.

Requires Minecraft 1.21.1 and NeoForge 21.1.x.

## Configuration

The update interval defaults to 500 ms. To change it, add a JVM argument (for example in Prism
Launcher → Edit Instance → Settings → Java → JVM arguments):

```
-Dcosmoskyfix.intervalMs=250
```

Lower values animate more smoothly but cost more FPS. `50` matches the original behaviour.

## Building

You need JDK 21, `curl` and bash.

```bash
./build.sh            # uses the version in VERSION
./build.sh 1.2.3      # or set one explicitly
```

The jar is written to `build/cosmoskyfix-<version>.jar`.

This project doesn't use Gradle or a decompiled Minecraft setup, so builds take seconds. `build.sh`
downloads three compile-time APIs (Sponge Mixin, NeoForge FML loader, NeoForge dist markers)
into `.deps/`, checks each one against a pinned SHA-256, and compiles with plain `javac`. The one
Minecraft type the mixin references, `ResourceLocation`, comes from an empty stub in `stubs/`. The
stub is used only at compile time and is never packaged; the game supplies the real class.

## Releasing

Releases are built by the **Build and release** GitHub Actions workflow
(`.github/workflows/release.yml`). It only runs when triggered manually:

1. Bump `VERSION` and commit, or plan to pass a version in step 3.
2. Go to **Actions → Build and release → Run workflow**.
3. Optionally enter a version; otherwise the `VERSION` file is used.

The workflow builds the jar with `build.sh` and publishes a GitHub release tagged `v<version>`,
with the jar attached and auto-generated notes. It refuses to overwrite an existing release.

## Project layout

```
src/main/java/.../CosmoSkyFix.java              empty @Mod entry point
src/main/java/.../mixin/SkyHandlerMixin.java    the throttle
src/main/resources/cosmoskyfix.mixins.json      mixin config (optional, client-only)
src/main/resources/META-INF/neoforge.mods.toml  mod metadata (${version} filled in at build time)
stubs/                                          compile-only Minecraft stand-ins
build.sh                                        javac-based build
```

## License

MIT. See [LICENSE](LICENSE). This project contains no Cosmonautics code; it only hooks one
of its methods at runtime.
