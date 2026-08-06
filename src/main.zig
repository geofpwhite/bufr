const std = @import("std");
const execute = @import("interpreter.zig").execute;
const Log = @import("log/log.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Configure the global logger. Toggle .Json / .KV and level as needed.
    Log.log.setMode(.KV);
    Log.log.setLevel(.Debug);

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // skip executable name
    if (args.next()) |arg| {
        Log.log.info("main", arg, null);
        try execute(arg, allocator);
        Log.log.info("main", "execution finished", null);
    } else {
        Log.log.errorf("main", "no file provided", null);
    }
}
