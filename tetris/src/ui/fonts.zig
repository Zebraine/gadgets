//! Embedded Chakra Petch fonts and their rayLib atlas handles.

const std = @import("std");
const rl = @import("raylib");

pub const Fonts = struct {
    /// SemiBold, rasterized near the size used by the HUD.
    small: rl.Font,
    /// Bold display face, rasterized for large numbers and headings.
    display: rl.Font,
    owns_small: bool,
    owns_display: bool,

    pub fn load() !Fonts {
        const fallback = try rl.getFontDefault();
        var fonts = Fonts{
            .small = fallback,
            .display = fallback,
            .owns_small = false,
            .owns_display = false,
        };

        if (rl.Font.fromMemory(".ttf", @embedFile("../assets/fonts/ChakraPetch-SemiBold.ttf"), 16, null)) |font| {
            fonts.small = font;
            fonts.owns_small = true;
            rl.setTextureFilter(font.texture, .bilinear);
        } else |err| {
            std.debug.print("Could not load small font: {s}\n", .{@errorName(err)});
        }

        if (rl.Font.fromMemory(".ttf", @embedFile("../assets/fonts/ChakraPetch-Bold.ttf"), 64, null)) |font| {
            fonts.display = font;
            fonts.owns_display = true;
            rl.setTextureFilter(font.texture, .bilinear);
        } else |err| {
            std.debug.print("Could not load display font: {s}\n", .{@errorName(err)});
        }

        return fonts;
    }

    pub fn deinit(self: *Fonts) void {
        if (self.owns_small) rl.unloadFont(self.small);
        if (self.owns_display and (!self.owns_small or self.display.texture.id != self.small.texture.id)) {
            rl.unloadFont(self.display);
        }
    }
};
