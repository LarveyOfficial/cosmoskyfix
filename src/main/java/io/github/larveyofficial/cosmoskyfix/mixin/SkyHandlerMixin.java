package io.github.larveyofficial.cosmoskyfix.mixin;

import net.minecraft.resources.ResourceLocation;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Cosmonautics regenerates its 64x64 star-plasma noise texture on the render thread every
 * game tick (20x/s), even when the custom sky is disabled. Throttle it to a fixed interval.
 * Override the interval with -Dcosmoskyfix.intervalMs=<ms>.
 */
@Mixin(targets = "dev.devce.rocketnautics.client.SkyHandler", remap = false)
public abstract class SkyHandlerMixin {
    @Unique
    private static final long cosmoskyfix$INTERVAL_NANOS =
            Long.getLong("cosmoskyfix.intervalMs", 500L) * 1_000_000L;

    @Unique
    private static long cosmoskyfix$lastRegen;

    @Shadow
    public static ResourceLocation STAR_PLASMA_TEXTURE_ID;

    @Inject(method = "ensureStarPlasmaTexture", at = @At("HEAD"), cancellable = true)
    private static void cosmoskyfix$throttle(CallbackInfo ci) {
        long now = System.nanoTime();
        // Always let the first build through so the texture exists.
        if (STAR_PLASMA_TEXTURE_ID != null && now - cosmoskyfix$lastRegen < cosmoskyfix$INTERVAL_NANOS) {
            ci.cancel();
            return;
        }
        cosmoskyfix$lastRegen = now;
    }
}
