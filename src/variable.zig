const std = @import("std");
const Type = @import("types.zig").Type;
pub const variable = struct {
    type: Type,
    name: []const u8,
    data: []u8,
};
