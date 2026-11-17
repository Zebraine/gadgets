//! Transient presentation effects: particles, banners, shake and pulses.

const std = @import("std");
const rl = @import("raylib");
const game_mod = @import("../game/game.zig");
const theme = @import("theme.zig");
const draw = @import("draw.zig");
const Fonts = @import("fonts.zig").Fonts;

const C = theme.C;

const Particle = struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    life: f32,
    max_life: f32,
    size: f32,
    angle: f32,
    spin: f32,
    color: rl.Color,
};

const MAX_PARTICLES = 192;

const Banner = struct {
    title_buf: [48]u8 = @splat(0),
    title_len: usize = 0,
    sub_buf: [48]u8 = @splat(0),
    sub_len: usize = 0,
    timer: f32 = 0,
    duration: f32 = 1.1,
    color: rl.Color = C.text,

    pub fn show(self: *Banner, heading: []const u8, caption: []const u8, color: rl.Color, duration: f32) void {
        self.title_len = @min(heading.len, self.title_buf.len);
        @memcpy(self.title_buf[0..self.title_len], heading[0..self.title_len]);
        self.sub_len = @min(caption.len, self.sub_buf.len);
        @memcpy(self.sub_buf[0..self.sub_len], caption[0..self.sub_len]);
        self.color = color;
        self.timer = duration;
        self.duration = duration;
    }

    fn update(self: *Banner, dt: f32) void {
        if (self.timer > 0) self.timer = @max(0, self.timer - dt);
    }

    fn title(self: *const Banner) []const u8 {
        return self.title_buf[0..self.title_len];
    }

    fn sub(self: *const Banner) []const u8 {
        return self.sub_buf[0..self.sub_len];
    }
};

pub const Effects = struct {
    particles: [MAX_PARTICLES]Particle = undefined,
    particle_count: usize = 0,

    banner: Banner = .{},
    shake: f32 = 0,
    shake_timer: f32 = 0,
    flash: f32 = 0,
    score_pulse: f32 = 0,
    level_pulse: f32 = 0,
    hold_pulse: f32 = 0,
    rng: std.Random.DefaultPrng,

    pub fn init(seed: u64) Effects {
        return .{
            .particle_count = 0,
            .banner = .{},
            .rng = std.Random.DefaultPrng.init(seed ^ 0xd1b5_4a32_d192_ed03),
        };
    }

    pub fn clear(self: *Effects) void {
        self.particle_count = 0;
        self.banner.timer = 0;
        self.shake = 0;
        self.shake_timer = 0;
        self.flash = 0;
        self.score_pulse = 0;
        self.level_pulse = 0;
        self.hold_pulse = 0;
    }

    pub fn update(self: *Effects, dt: f32) void {
        var i: usize = 0;
        while (i < self.particle_count) {
            const p = &self.particles[i];
            p.life -= dt;
            if (p.life <= 0) {
                self.particles[i] = self.particles[self.particle_count - 1];
                self.particle_count -= 1;
                continue;
            }

            p.pos.x += p.vel.x * dt;
            p.pos.y += p.vel.y * dt;
            p.vel.y += 620 * dt;
            p.vel.x *= 1.0 - @min(0.9, dt * 0.8);
            p.angle += p.spin * dt;
            i += 1;
        }

        self.banner.update(dt);
        self.flash = @max(0, self.flash - dt * 2.8);
        self.shake_timer = @max(0, self.shake_timer - dt);
        self.shake = @max(0, self.shake - dt * 14);
        self.score_pulse = @max(0, self.score_pulse - dt * 2.5);
        self.level_pulse = @max(0, self.level_pulse - dt * 1.8);
        self.hold_pulse = @max(0, self.hold_pulse - dt * 3.2);
    }

    pub fn kickShake(self: *Effects, amount: f32) void {
        self.shake = @max(self.shake, amount);
        self.shake_timer = 0.28;
    }

    fn spawnParticle(self: *Effects, p: Particle) void {
        if (self.particle_count >= self.particles.len) return;
        self.particles[self.particle_count] = p;
        self.particle_count += 1;
    }

    pub fn burstRows(self: *Effects, game: *const game_mod.Game, info: game_mod.ClearInfo) void {
        const rand = self.rng.random();
        var rows = info.rows;
        while (rows != 0) {
            const row: usize = @intCast(@ctz(rows));
            rows &= rows - 1;

            for (0..game_mod.COLS) |col| {
                const kind = game.cell(col, row) orelse continue;
                const visual = theme.pieceVisual(kind);
                const center_x = theme.BOARD_X + @as(f32, @floatFromInt(col)) * theme.CELL + theme.CELL / 2;
                const center_y = theme.BOARD_Y + @as(f32, @floatFromInt(row)) * theme.CELL + theme.CELL / 2;

                const amount: usize = 2;
                for (0..amount) |_| {
                    const spread = rand.float(f32);
                    self.spawnParticle(.{
                        .pos = draw.v2(center_x + (spread - 0.5) * 18, center_y + (rand.float(f32) - 0.5) * 16),
                        .vel = draw.v2((spread - 0.5) * 380, -90 - rand.float(f32) * 260),
                        .life = 0.35 + rand.float(f32) * 0.55,
                        .max_life = 0.9,
                        .size = 2.0 + rand.float(f32) * 5.0,
                        .angle = rand.float(f32) * std.math.tau,
                        .spin = (rand.float(f32) - 0.5) * 16,
                        .color = if (rand.float(f32) < 0.22) C.text else visual.base,
                    });
                }

                const streak_speed = 80 + rand.float(f32) * 260;
                self.spawnParticle(.{
                    .pos = draw.v2(center_x, center_y),
                    .vel = draw.v2((rand.float(f32) - 0.5) * 280, -180 - streak_speed * 0.4),
                    .life = 0.2 + rand.float(f32) * 0.25,
                    .max_life = 0.45,
                    .size = 1.5 + rand.float(f32) * 2.5,
                    .angle = 0,
                    .spin = 0,
                    .color = C.text.fade(0.8),
                });
            }
        }
    }

    pub fn drawParticles(self: *const Effects) void {
        if (self.particle_count == 0) return;
        rl.beginBlendMode(.additive);
        for (self.particles[0..self.particle_count]) |particle| {
            const t = @max(0.0, particle.life / particle.max_life);
            const p = draw.rect(
                particle.pos.x - particle.size / 2,
                particle.pos.y - particle.size / 2,
                particle.size,
                particle.size,
            );
            rl.drawRectanglePro(p, draw.v2(particle.size / 2, particle.size / 2), particle.angle, particle.color.fade(t));
            rl.drawCircleV(particle.pos, particle.size * 1.7, particle.color.fade(t * 0.06));
        }
        rl.endBlendMode();
    }

    pub fn drawBanner(self: *const Effects, fonts: *const Fonts) void {
        const banner = &self.banner;
        if (banner.timer <= 0 or banner.title_len == 0) return;

        const elapsed = banner.duration - banner.timer;
        const fade_in = @min(1.0, elapsed / 0.14);
        const fade_out = @min(1.0, banner.timer / 0.24);
        const alpha = @min(fade_in, fade_out);
        const rise = (1.0 - fade_in) * 8.0;

        const center_x = theme.BOARD_X + theme.BOARD_W / 2;
        const y = theme.BOARD_Y + 182 - rise;
        const panel = draw.rect(center_x - 120, y, 240, 76);
        rl.drawRectangleRounded(panel, 0.18, 6, C.surface.fade(0.92 * alpha));
        rl.drawRectangleRoundedLinesEx(panel, 0.18, 6, 1, banner.color.fade(0.55 * alpha));
        rl.drawLineEx(draw.v2(panel.x + 28, panel.y + 1), draw.v2(panel.x + panel.width - 28, panel.y + 1), 1.5, banner.color.fade(0.6 * alpha));

        draw.drawTextCentered(fonts.display, banner.title(), center_x, y + 17, 24, 2.0, banner.color.fade(alpha));
        draw.drawTextCentered(fonts.small, banner.sub(), center_x, y + 49, 10.5, 1.6, C.text.fade(0.78 * alpha));
    }
};
