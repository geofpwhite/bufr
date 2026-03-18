const std = @import("std");
const execute = @import("interpreter.zig").execute;
const Log = @import("log/log.zig");

pub fn main() !void {
    // std.debug.print("{}", try isLucky(5));
    // std.debug.print("asdflkjadsf", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Initialize logger (defaults are reasonable; set explicitly here).
    // Toggle between `.Json` and `.KV` as desired.
    Log.log.setMode(.KV);
    Log.log.setLevel(Log.Level.Debug);

    var args = try std.process.argsWithAllocator(allocator);
    // var child = std.process.Child.initWithAllocator(allocator, args);
    defer args.deinit();

    _ = args.next();
    if (args.next()) |arg| {
        // Log start of execution (target = "main", message = path)
        try Log.log.info("main", arg);
        try execute(arg, allocator);
        // Log finish
        try Log.log.info("main", "execution finished");
    } else {
        try Log.log.errorf("main", "no file provided");
    }
    // try execute(args);
}
