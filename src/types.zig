const std = @import("std");
pub const token = []const u8;
pub const Type = enum {
    Integer,
    Float,
    Matrix,
    Bool,
    NULL,

    pub fn matrix(allocator: std.mem.Allocator, rows: usize, cols: usize, elementType: MatrixType) !Matrix {
        return Matrix.new(allocator, rows, cols, elementType);
    }
};

pub const matrixEvalError = error{
    InvalidDimensions,
};

pub const MatrixType = enum {
    Float,
    Integer,
};

pub const Matrix = struct {
    type: MatrixType,
    rows: usize,
    cols: usize,
    data: [][]u64,

    pub fn eql(self: Matrix, other: Matrix) bool {
        if (self.rows != other.rows or self.cols != other.cols or self.type != other.type) {
            return false;
        }
        for (0..self.rows) |row|
            for (0..self.cols) |col|
                if (self.data[row][col] != other.data[row][col])
                    return false;

        return true;
    }

    pub fn new(allocator: std.mem.Allocator, rows: usize, cols: usize, elementType: MatrixType) !Matrix {
        var full_data = std.ArrayList([]u64).empty;
        var data = std.ArrayList(u64).empty;
        for (0..rows) |_| {
            for (0..cols) |_| {
                try data.append(allocator, @as(u64, 0));
            }
            try full_data.append(allocator, try data.toOwnedSlice(allocator));
            data = std.ArrayList(u64).empty;
        }
        return Matrix{
            .type = elementType,
            .rows = rows,
            .cols = cols,
            .data = try full_data.toOwnedSlice(allocator),
        };
    }

    pub fn add(left: Matrix, right: Matrix, allocator: std.mem.Allocator) !Matrix {
        if (left.rows != right.rows or left.cols != right.cols or left.type != right.type) {
            return matrixEvalError.InvalidDimensions;
        }
        var result = try Matrix.new(allocator, left.rows, left.cols, left.type);
        // const t: type = if (left.type == .Float) f64 else i64;
        for (0..left.rows) |row| {
            for (0..left.cols) |col| {
                if (left.type == .Float) {
                    const f1: f64 = @bitCast(left.data[row][col]);
                    const f2: f64 = @bitCast(right.data[row][col]);
                    result.data[row][col] = @bitCast(f1 + f2);
                    continue;
                }
                const f1: i64 = @bitCast(left.data[row][col]);
                const f2: i64 = @bitCast(right.data[row][col]);
                result.data[row][col] = @bitCast(f1 + f2);
            }
        }

        return result;
    }

    pub fn deinit(self: Matrix, allocator: std.mem.Allocator) void {
        for (self.data) |row| {
            allocator.free(row);
        }
        allocator.free(self.data);
    }

    pub fn toString(_: Matrix) []const u8 {
        return "matrix";
    }
};
