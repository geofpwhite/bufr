const std = @import("std");
const execute = @import("interpreter.zig").execute;
pub fn main() !void {
    // std.debug.print("{}", try isLucky(5));
    // std.debug.print("asdflkjadsf", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    var args = try std.process.argsWithAllocator(allocator);
    // var child = std.process.Child.initWithAllocator(allocator, args);
    defer args.deinit();

    _ = args.next();
    if (args.next()) |arg| {
        try execute(arg, allocator);
    }
    // try execute(args);
}
