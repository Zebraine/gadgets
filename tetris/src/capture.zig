//! Offscreen 1200x800 render target and PNG export for deterministic captures.

const rl = @import("raylib");

pub const Target = struct {
    target: rl.RenderTexture2D,

    pub fn init(width: i32, height: i32) !Target {
        const target = try rl.loadRenderTexture(width, height);
        rl.setTextureFilter(target.texture, .bilinear);
        return .{ .target = target };
    }

    pub fn deinit(self: *Target) void {
        rl.unloadRenderTexture(self.target);
    }

    pub fn begin(self: *Target) void {
        rl.beginTextureMode(self.target);
    }

    pub fn end(self: *Target) void {
        _ = self;
        rl.endTextureMode();
    }

    pub fn save(self: *Target, path: [:0]const u8) !void {
        var image = try rl.loadImageFromTexture(self.target.texture);
        defer rl.unloadImage(image);

        // OpenGL render textures are bottom-up. Flattening alpha also prevents
        // viewers from compositing translucent blend leftovers over white.
        rl.imageFlipVertical(&image);
        rl.imageFormat(&image, .uncompressed_r8g8b8);
        if (!rl.exportImage(image, path)) return error.ScreenshotExportFailed;
    }
};
