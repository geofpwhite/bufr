const std = @import("std");
pub const token = []const u8;
pub const Type = enum {
    Integer,
    Float,
    Matrix,
    Array,
    NULL,

    pub fn matrix(allocator: std.mem.Allocator, rows: usize, cols: usize) !Matrix {
        return Matrix.new(allocator, rows, cols);
    }
};

pub const Matrix = struct {
    type: Type,
    rows: usize,
    cols: usize,
    data: [][][8]u8,

    pub fn new(allocator: std.mem.Allocator, rows: usize, cols: usize) !Matrix {
        var full_data = std.ArrayList([][8]u8).empty;
        var data = std.ArrayList([8]u8).empty;
        for (0..rows) |_| {
            for (0..cols) |_| {
                try data.append(allocator, [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 });
            }
            try full_data.append(allocator, try data.toOwnedSlice(allocator));
            data = std.ArrayList([8]u8).empty;
        }
        return Matrix{
            .type = Type.Matrix,
            .rows = rows,
            .cols = cols,
            .data = try full_data.toOwnedSlice(allocator),
        };
    }

    pub fn toString(_: Matrix) []const u8 {
        return "matrix";
    }
};
