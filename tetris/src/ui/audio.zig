//! Procedurally synthesized sound effects. No external audio files are used.

const std = @import("std");
const rl = @import("raylib");

const SAMPLE_RATE: f32 = 44_100;

pub const Sfx = enum {
    move,
    rotate,
    lock,
    hard_drop,
    hold,
    clear,
    tetris,
    level_up,
    game_over,
};

const WaveShape = enum { sine, triangle, square, saw };

fn addTone(
    out: []f32,
    start: f32,
    duration: f32,
    f0: f32,
    f1: f32,
    shape: WaveShape,
    gain: f32,
) void {
    if (start < 0 or duration <= 0 or out.len == 0) return;
    const first: usize = @intFromFloat(start * SAMPLE_RATE);
    if (first >= out.len) return;
    const count: usize = @intFromFloat(duration * SAMPLE_RATE);
    const end = @min(out.len, first + count);

    var phase: f32 = 0;
    for (first..end) |i| {
        const local: f32 = @floatFromInt(i - first);
        const t = local / SAMPLE_RATE;
        const progress = @min(1.0, t / duration);
        const freq = f0 + (f1 - f0) * progress;

        phase += freq / SAMPLE_RATE;
        phase -= @floor(phase);
        const raw: f32 = switch (shape) {
            .sine => std.math.sin(phase * std.math.tau),
            .triangle => 4.0 * @abs(phase - 0.5) - 1.0,
            .square => if (phase < 0.5) 1.0 else -1.0,
            .saw => phase * 2.0 - 1.0,
        };

        const attack = @min(1.0, t / 0.006);
        const release = std.math.pow(f32, 1.0 - progress, 1.7);
        out[i] += raw * gain * attack * release;
    }
}

fn addNoise(out: []f32, start: f32, duration: f32, gain: f32) void {
    if (start < 0 or duration <= 0 or out.len == 0) return;
    const first: usize = @intFromFloat(start * SAMPLE_RATE);
    if (first >= out.len) return;
    const count: usize = @intFromFloat(duration * SAMPLE_RATE);
    const end = @min(out.len, first + count);

    var state: u32 = 0x6d2b_79f5;
    for (first..end) |i| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        const raw = @as(f32, @floatFromInt(state >> 8)) / 8_388_608.0 - 1.0;
        const progress: f32 = @as(f32, @floatFromInt(i - first)) / @as(f32, @floatFromInt(end - first));
        out[i] += raw * gain * (1.0 - progress) * (1.0 - progress);
    }
}

fn sfxDuration(kind: Sfx) f32 {
    return switch (kind) {
        .move => 0.06,
        .rotate => 0.13,
        .lock => 0.15,
        .hard_drop => 0.22,
        .hold => 0.15,
        .clear => 0.52,
        .tetris => 0.9,
        .level_up => 0.62,
        .game_over => 1.05,
    };
}

fn makeSfx(allocator: std.mem.Allocator, kind: Sfx) !rl.Sound {
    const duration = sfxDuration(kind);
    const frames: usize = @intFromFloat(duration * SAMPLE_RATE);
    const mix = try allocator.alloc(f32, frames);
    defer allocator.free(mix);
    @memset(mix, 0);

    switch (kind) {
        .move => {
            addTone(mix, 0, 0.035, 900, 760, .triangle, 0.14);
        },
        .rotate => {
            addTone(mix, 0, 0.045, 470, 560, .triangle, 0.13);
            addTone(mix, 0.035, 0.07, 720, 980, .sine, 0.10);
        },
        .lock => {
            addTone(mix, 0, 0.11, 138, 64, .sine, 0.42);
            addNoise(mix, 0, 0.055, 0.15);
        },
        .hard_drop => {
            addTone(mix, 0, 0.16, 300, 66, .saw, 0.16);
            addTone(mix, 0.01, 0.16, 125, 54, .sine, 0.32);
            addNoise(mix, 0, 0.075, 0.15);
        },
        .hold => {
            addTone(mix, 0, 0.05, 340, 460, .triangle, 0.12);
            addTone(mix, 0.045, 0.075, 560, 700, .sine, 0.10);
        },
        .clear => {
            const notes = [4]f32{ 523.25, 659.25, 783.99, 1046.50 };
            for (notes, 0..) |freq, i| {
                addTone(mix, @as(f32, @floatFromInt(i)) * 0.055, 0.2, freq, freq, .triangle, 0.16);
                addTone(mix, @as(f32, @floatFromInt(i)) * 0.055, 0.16, freq * 2, freq * 2, .sine, 0.035);
            }
            addTone(mix, 0, 0.33, 130.81, 130.81, .sine, 0.10);
        },
        .tetris => {
            const notes = [6]f32{ 523.25, 659.25, 783.99, 1046.50, 1318.51, 1567.98 };
            for (notes, 0..) |freq, i| {
                const start = @as(f32, @floatFromInt(i)) * 0.062;
                addTone(mix, start, 0.28, freq, freq, .triangle, 0.16);
                addTone(mix, start + 0.01, 0.22, freq * 2, freq * 2, .sine, 0.04);
            }
            addTone(mix, 0, 0.55, 65.41, 65.41, .sine, 0.13);
            addTone(mix, 0.31, 0.5, 1046.5, 1568, .sine, 0.05);
        },
        .level_up => {
            const notes = [5]f32{ 392.00, 523.25, 659.25, 783.99, 1046.50 };
            for (notes, 0..) |freq, i| {
                addTone(mix, @as(f32, @floatFromInt(i)) * 0.065, 0.27, freq, freq, .triangle, 0.14);
            }
            addTone(mix, 0, 0.35, 98, 98, .sine, 0.10);
        },
        .game_over => {
            const notes = [4]f32{ 329.63, 261.63, 196.00, 130.81 };
            for (notes, 0..) |freq, i| {
                const start = @as(f32, @floatFromInt(i)) * 0.15;
                addTone(mix, start, 0.36, freq, freq * 0.985, .saw, 0.10);
                addTone(mix, start, 0.38, freq * 0.5, freq * 0.5, .sine, 0.14);
            }
            addTone(mix, 0.35, 0.65, 65.41, 32.7, .sine, 0.18);
        },
    }

    const pcm = try allocator.alloc(i16, frames);
    defer allocator.free(pcm);
    for (mix, 0..) |sample, i| {
        const shaped = std.math.tanh(sample * 1.15) * 0.9;
        pcm[i] = @intFromFloat(std.math.clamp(shaped, -1.0, 1.0) * 32767.0);
    }

    const wave = rl.Wave{
        .frameCount = @intCast(frames),
        .sampleRate = @intFromFloat(SAMPLE_RATE),
        .sampleSize = 16,
        .channels = 1,
        .data = @ptrCast(pcm.ptr),
    };
    const sound = rl.loadSoundFromWave(wave);
    if (!rl.isSoundValid(sound)) {
        rl.unloadSound(sound);
        return error.InvalidSound;
    }
    return sound;
}

/// Owns the audio device and the generated sound bank. App only sees this
/// facade and can therefore remain independent from raudio details.
pub const AudioSystem = struct {
    device_started: bool,
    muted: bool,
    bank: ?SoundBank,

    pub fn init(allocator: std.mem.Allocator) AudioSystem {
        rl.initAudioDevice();
        var system = AudioSystem{
            .device_started = true,
            .muted = false,
            .bank = null,
        };

        if (!rl.isAudioDeviceReady()) {
            std.debug.print("No audio device found; continuing silently.\n", .{});
            return system;
        }

        system.bank = SoundBank.init(allocator) catch |err| blk: {
            std.debug.print("Audio unavailable ({s}); continuing silently.\n", .{@errorName(err)});
            break :blk null;
        };
        if (system.bank != null) rl.setMasterVolume(0.72);
        return system;
    }

    pub fn deinit(self: *AudioSystem) void {
        if (self.bank) |*bank| bank.deinit();
        if (self.device_started) rl.closeAudioDevice();
    }

    pub fn play(self: *AudioSystem, id: Sfx) void {
        if (self.muted) return;
        if (self.bank) |*bank| bank.play(id);
    }

    pub fn toggleMute(self: *AudioSystem) void {
        self.muted = !self.muted;
        if (self.bank != null) rl.setMasterVolume(if (self.muted) 0.0 else 0.72);
    }
};

const SoundBank = struct {
    sounds: [9]rl.Sound = undefined,

    fn init(allocator: std.mem.Allocator) !SoundBank {
        var bank: SoundBank = .{};
        var created: usize = 0;
        errdefer {
            for (bank.sounds[0..created]) |sound| rl.unloadSound(sound);
        }

        inline for (@typeInfo(Sfx).@"enum".field_names) |name| {
            const id: Sfx = @field(Sfx, name);
            bank.sounds[@backingInt(id)] = try makeSfx(allocator, id);
            created += 1;
        }
        return bank;
    }

    fn deinit(self: *SoundBank) void {
        for (self.sounds) |sound| rl.unloadSound(sound);
    }

    fn play(self: *SoundBank, id: Sfx) void {
        rl.playSound(self.sounds[@backingInt(id)]);
    }
};
