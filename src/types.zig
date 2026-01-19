const std = @import("std");
pub const token = []const u8;
pub const Type = enum {
    Integer,
    Float,
    Array,
    NULL,
};
