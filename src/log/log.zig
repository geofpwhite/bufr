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

    pub fn init(mode: Mode, level: Level, target: []const u8) Logger {
        return Logger{ .mode = mode, .level = level, .target = target };
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

    fn write(buf: []const u8) void {
        std.fs.File.stdout().writeAll(buf) catch return;
    }

    fn writeFmt(comptime fmt: []const u8, args: anytype) void {
        var buf: [512]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, fmt, args) catch return;
        write(s);
    }

    pub fn log(self: *Logger, level: Level, target: []const u8, message: []const u8, fields: ?[]const Field) void {
        if (@intFromEnum(level) < @intFromEnum(self.level)) return;

        const used_target = if (target.len == 0) self.target else target;
        const ts = std.time.timestamp();

        if (self.mode == .Json) {
            writeFmt("{{\"timestamp\":{d},\"level\":\"{s}\",\"target\":\"{s}\",\"message\":\"{s}\"", .{
                ts, levelToString(level), used_target, message,
            });
            if (fields) |f| {
                if (f.len > 0) {
                    write(",\"fields\":{");
                    for (f, 0..) |fld, i| {
                        if (i > 0) write(",");
                        writeFmt("\"{s}\":\"{s}\"", .{ fld.key, fld.value });
                    }
                    write("}");
                }
            }
            write("}\n");
        } else {
            // KV format
            writeFmt("ts={d} level={s} target={s} msg=\"{s}\"", .{
                ts, levelToString(level), used_target, message,
            });
            if (fields) |f| {
                for (f) |fld| {
                    writeFmt(" {s}=\"{s}\"", .{ fld.key, fld.value });
                }
            }
            write("\n");
        }
    }

    pub fn debug(self: *Logger, target: []const u8, message: []const u8, fields: ?[]const Field) void {
        self.log(.Debug, target, message, fields);
    }

    pub fn info(self: *Logger, target: []const u8, message: []const u8, fields: ?[]const Field) void {
        self.log(.Info, target, message, fields);
    }

    pub fn warn(self: *Logger, target: []const u8, message: []const u8, fields: ?[]const Field) void {
        self.log(.Warn, target, message, fields);
    }

    pub fn errorf(self: *Logger, target: []const u8, message: []const u8, fields: ?[]const Field) void {
        self.log(.Error, target, message, fields);
    }
};

// Default global logger instance
pub var log: Logger = Logger{
    .mode = .KV,
    .level = .Debug,
    .target = "bufr",
};

test "logger KV format - debug level" {
    var logger = Logger.init(.KV, .Debug, "test");
    // Should not panic; just verify it runs without error
    logger.debug("test", "hello from debug", null);
}

test "logger KV format - with fields" {
    var logger = Logger.init(.KV, .Debug, "test");
    const fields = [_]Field{
        .{ .key = "key1", .value = "val1" },
        .{ .key = "key2", .value = "val2" },
    };
    logger.info("test", "message with fields", &fields);
}

test "logger JSON format" {
    var logger = Logger.init(.Json, .Debug, "test");
    logger.info("test", "json message", null);
}

test "logger JSON format - with fields" {
    var logger = Logger.init(.Json, .Debug, "test");
    const fields = [_]Field{
        .{ .key = "foo", .value = "bar" },
    };
    logger.warn("test", "json with fields", &fields);
}

test "logger level filtering - suppresses below threshold" {
    var logger = Logger.init(.KV, .Error, "test");
    // These should be filtered out (no output, no panic)
    logger.debug("test", "should be suppressed", null);
    logger.info("test", "should be suppressed", null);
    logger.warn("test", "should be suppressed", null);
}

test "logger level filtering - passes at threshold" {
    var logger = Logger.init(.KV, .Warn, "test");
    logger.warn("test", "should appear", null);
    logger.errorf("test", "should appear", null);
}

test "logger uses default target when empty" {
    var logger = Logger.init(.KV, .Debug, "default-target");
    // empty target string should fall back to logger's own target
    logger.debug("", "using default target", null);
}

test "logger setMode and setLevel" {
    var logger = Logger.init(.KV, .Debug, "test");
    logger.setMode(.Json);
    logger.setLevel(.Info);
    logger.debug("test", "suppressed by level", null);
    logger.info("test", "visible", null);
}

test "logger errorf" {
    var logger = Logger.init(.KV, .Debug, "test");
    logger.errorf("test", "error message", null);
}

test "global log singleton is usable" {
    log.debug("test", "global singleton works", null);
    log.info("test", "info via global", null);
}
