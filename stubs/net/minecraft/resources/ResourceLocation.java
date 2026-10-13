package net.minecraft.resources;

/**
 * Compile-time stand-in for Minecraft's ResourceLocation so the mixin can @Shadow a field of
 * that type without pulling in a deobfuscated Minecraft jar. Never packaged into the mod; the
 * real class is used at runtime.
 */
public final class ResourceLocation {}
