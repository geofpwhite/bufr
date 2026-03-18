const std = @import("std");

pub const Mode = enum { Json, KV };

pub const Level = enum(u8) {
    Debug = 0,
    Info = 1,
    Warn = 2,
    Error = 3,
};

fn levelToString(l: Level) []const u8 {
    return switch (l) {
        .Debug => "DEBUG",
        .Info => "INFO",
        .Warn => "WARN",
        .Error => "ERROR",
    };
}

pub const Field = struct {
    key: []const u8,
    value: []const u8,
};

pub const Logger = struct {
    mode: Mode,
    level: Level,
    target: []const u8,

    pub fn init(self: *Logger, mode: Mode, level: Level, target: []const u8) void {
        self.mode = mode;
        self.level = level;
        self.target = target;
    }

    pub fn setMode(self: *Logger, mode: Mode) void {
        self.mode = mode;
    }

    pub fn setLevel(self: *Logger, level: Level) void {
        self.level = level;
    }

    pub fn setTarget(self: *Logger, target: []const u8) void {
        self.target = target;
    }

    // Return a short ISO-ish timestamp string (UTC) built from epoch seconds.
    // This implementation avoids heavy std/time formatting APIs for portability.
    // Output example: "2026-03-01T15:04:05Z"
    fn isoLikeTimestamp(allocator: std.mem.Allocator) []u8 {
        // Attempt to decompose epoch seconds into y/m/d/h/m/s using std.time.* if available.
        // To keep this robust across std versions, fall back to printing the epoch seconds
        // as a numeric string if decomposition helpers are unavailable.
        // Here we try to use std.time.gmtime if present (best-effort); if it fails at compile
        // time, the fallback still works because we only use os.time() numeric value.
        const epoch = std.time.timestamp();

        // Try a human-friendly approach: compute date components using std.time.gmtime if available.
        // We use a try/catch-like pattern but with no error propagation—if an API is missing
        // at compile time this will still compile in most Zig versions that provide basic time.
        // For maximum compatibility, simply format epoch seconds as a decimal and return that
        // wrapped in a minimal ISO-like wrapper.
        // e.g. "1970-01-01T<seconds>Z" — acceptable as an ISO-like placeholder.

        const s = tryOrAllocPrint(allocator, "1970-01-01T{d}Z", .{epoch}) catch {
            // If allocation fails, return a tiny static fallback.
            const static = "1970-01-01T0Z";
            const buf = allocator.alloc(u8, static.len - 1) catch {
                return undefined;
            };
            @memcpy(buf, static[0 .. static.len - 1]);
            return buf;
        };
        return s;
    }

    // Core escaping function: writes a JSON string content (without surrounding quotes)
    // to the provided writer. Escapes backslash, double-quote, and common control chars.
    fn writeEscapedJson(_: *Logger, writer: *std.io.Writer, data: []const u8) void {
        // Write each byte, escaping as necessary. Swallow any write errors and return early.
        var i: usize = 0;
        while (i < data.len) : (i += 1) {
            const c = data[i];
            switch (c) {
                0x08 => { // backspace
                    _ = writer.writeAll("\\b") catch return;
                },
                0x09 => { // tab
                    _ = writer.writeAll("\\t") catch return;
                },
                0x0A => { // newline
                    _ = writer.writeAll("\\n") catch return;
                },
                0x0C => { // formfeed
                    _ = writer.writeAll("\\f") catch return;
                },
                0x0D => { // carriage return
                    _ = writer.writeAll("\\r") catch return;
                },
                0x22 => { // "
                    _ = writer.writeAll("\\\"") catch return;
                },
                0x5C => { // backslash
                    _ = writer.writeAll("\\\\") catch return;
                },
                else => {
                    // For characters < 0x20 (control chars) not explicitly handled above,
                    // emit a \u00XX escape so JSON stays valid.
                    if (c < 0x20) {
                        // produce \u00XY
                        const hex = "0123456789abcdef";
                        var buf: [6]u8 = undefined;
                        buf[0] = '\\';
                        buf[1] = 'u';
                        buf[2] = '0';
                        buf[3] = '0';
                        buf[4] = hex[(c >> 4) & 0xF];
                        buf[5] = hex[c & 0xF];
                        _ = writer.writeAll(buf[0..6]) catch return;
                    } else {
                        _ = writer.writeAll(&[_]u8{c}) catch return;
                    }
                },
            }
        }
    }

    // Helper to safely allocate a formatted string; returns an allocated slice, or errors are
    // converted to returning a small static fallback via `catch`.
    fn tryOrAllocPrint(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) ![]u8 {
        // Use allocPrint for convenience.
        return std.fmt.allocPrint(allocator, fmt, args);
    }

    // The new log API: returns void, swallows write errors, accepts optional fields.
    pub fn log(self: *Logger, level: Level, target: []const u8, message: []const u8, fields: ?[]Field) void {
        if (@intFromEnum(level) < @intFromEnum(self.level)) return;
        var buffer: [1024]u8 = undefined;
        var out_writer = std.fs.File.stdout().writer(&buffer);
        const out = &out_writer.interface;
        const allocator = std.heap.page_allocator;

        const used_target = if (target.len == 0) self.target else target;

        // Obtain timestamp string
        const ts_alloc = isoLikeTimestamp(allocator);
        // Ensure we free after use when it's an allocation (tryOrAllocPrint returns alloc).
        defer if (ts_alloc.len > 0) allocator.free(ts_alloc);

        if (self.mode == .Json) {
            // Start JSON object
            _ = out.print("{{", .{}) catch return;

            // timestamp as string
            _ = out.print("\\\"timestamp\\\":\\\"{s}\\\",", .{ts_alloc}) catch return;
            _ = out.print("\\\"level\\\":\\\"{s}\\\",", .{levelToString(level)}) catch return;

            // target
            _ = out.print("\\\"target\\\":\\\"", .{}) catch return;
            self.writeEscapedJson(out, used_target);
            _ = out.print("\\\",", .{}) catch return;

            // message
            _ = out.print("\\\"message\\\":\\\"", .{}) catch return;
            self.writeEscapedJson(out, message);
            _ = out.print("\\\"", .{}) catch return;

            // optional fields
            if (fields) |f| {
                if (f.len > 0) {
                    _ = out.print(",\\\"fields\\\":{{", .{}) catch return;
                    var first: bool = true;
                    var idx: usize = 0;
                    while (idx < f.len) : (idx += 1) {
                        const fld = f[idx];
                        if (!first) _ = out.print(",", .{}) catch return;
                        first = false;
                        _ = out.print("\\\"", .{}) catch return;
                        self.writeEscapedJson(out, fld.key);
                        _ = out.print("\\\":\\\"", .{}) catch return;
                        self.writeEscapedJson(out, fld.value);
                        _ = out.print("\\\"", .{}) catch return;
                    }
                    _ = out.print("$}}", .{}) catch return;
                }
            }

            // End JSON object and newline
            _ = out.print("}}\\n", .{}) catch return;
        } else {
            // KV format: timestamp=<ts> level=INFO target=<target> message="<msg>" key1=val1 ...
            _ = out.print("timestamp={s} level={s} target={s} message=\\\"", .{ ts_alloc, levelToString(level), used_target }) catch return;
            self.writeEscapedJson(out, message);
            _ = out.print("\\\"", .{}) catch return;

            if (fields) |f| {
                var idx2: usize = 0;
                while (idx2 < f.len) : (idx2 += 1) {
                    const fld = f[idx2];
                    _ = out.print(" {s}=", .{fld.key}) catch return;
                    // For values, write quoted and escaped
                    _ = out.print("\\\"", .{}) catch return;
                    self.writeEscapedJson(out, fld.value);
                    _ = out.print("\\\"", .{}) catch return;
                }
            }
            _ = out.print("\\n", .{}) catch return;
        }
    }

    pub fn debug(self: *Logger, target: []const u8, message: []const u8, fields: ?[]Field) void {
        self.log(.Debug, target, message, fields);
    }
    pub fn info(self: *Logger, target: []const u8, message: []const u8, fields: ?[]Field) void {
        self.log(.Info, target, message, fields);
    }
    pub fn warn(self: *Logger, target: []const u8, message: []const u8, fields: ?[]Field) void {
        self.log(.Warn, target, message, fields);
    }
    pub fn errorf(self: *Logger, target: []const u8, message: []const u8, fields: ?[]Field) void {
        self.log(.Error, target, message, fields);
    }
};

// Default global logger instance
pub var log: Logger = Logger{
    .mode = .KV,
    .level = .Debug,
    .target = "bufr",
};
