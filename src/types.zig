const std = @import("std");
const Log = @import("log/log.zig");
pub const token = []const u8;
pub const Type = enum {
    Integer,
    Float,
    Matrix,
    Bool,
    String,
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

    pub fn from(allocator: std.mem.Allocator, other: Matrix) !Matrix {
        const clone = Matrix{
            .type = other.type,
            .rows = other.rows,
            .cols = other.cols,
            .data = try allocator.alloc([]u64, other.rows),
        };
        for (0..clone.rows) |row| {
            clone.data[row] = try allocator.alloc(u64, clone.cols);
            for (0..clone.cols) |col| {
                clone.data[row][col] = other.data[row][col];
            }
        }
        return clone;
    }

    pub fn new(allocator: std.mem.Allocator, rows: usize, cols: usize, values: ?[][]const u8) !Matrix {
        Log.log.debug("types", "matrix new called", null);
        var full_data = std.ArrayList([]u64).empty;
        var data = std.ArrayList(u64).empty;
        for (0..rows) |_| {
            for (0..cols) |_| {
                try data.append(allocator, @as(u64, 0));
            }
            try full_data.append(allocator, try data.toOwnedSlice(allocator));
            data = std.ArrayList(u64).empty;
        }
        //TODO: scan values & determine type
        if (values) |vs| {
            // const total_nums = rows * cols;

            for (vs) |value| {
                Log.log.debug("types", value, null);
            }
        }
        const t = MatrixType.Integer;
        return Matrix{
            .rows = rows,
            .cols = cols,
            .data = try full_data.toOwnedSlice(allocator),
            .type = t,
        };
    }

    pub fn add(left: Matrix, right: Matrix, allocator: std.mem.Allocator) !Matrix {
        if (left.rows != right.rows or left.cols != right.cols or left.type != right.type) {
            return matrixEvalError.InvalidDimensions;
        }
        var result = try Matrix.from(allocator, left);
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

    pub fn subtract(left: Matrix, right: Matrix, allocator: std.mem.Allocator) !Matrix {
        if (left.rows != right.rows or left.cols != right.cols or left.type != right.type) {
            return matrixEvalError.InvalidDimensions;
        }
        var result = try Matrix.from(allocator, left);
        // const t: type = if (left.type == .Float) f64 else i64;
        for (0..left.rows) |row| {
            for (0..left.cols) |col| {
                if (left.type == .Float) {
                    const f1: f64 = @bitCast(left.data[row][col]);
                    const f2: f64 = @bitCast(right.data[row][col]);
                    result.data[row][col] = @bitCast(f1 - f2);
                    continue;
                }
                const f1: i64 = @bitCast(left.data[row][col]);
                const f2: i64 = @bitCast(right.data[row][col]);
                result.data[row][col] = @bitCast(f1 - f2);
            }
        }
        return result;
    }

    pub fn multiply(left: Matrix, right: Matrix, allocator: std.mem.Allocator) !Matrix {
        if (left.cols != right.rows) {
            return matrixEvalError.InvalidDimensions;
        }
        var result = try Matrix.new(allocator, left.rows, right.cols, null);
        Log.log.debug("types", "matrix multiply start", null);
        for (0..left.rows) |row| {
            for (0..right.cols) |col| {
                var sum: i64 = 0;
                for (0..left.cols) |k| {
                    if (left.type == .Float) {
                        const f1: f64 = @bitCast(left.data[row][k]);
                        const f2: f64 = @bitCast(right.data[k][col]);
                        sum += @bitCast(f1 * f2);
                    } else {
                        const f1: i64 = @bitCast(left.data[row][k]);
                        const f2: i64 = @bitCast(right.data[k][col]);
                        sum += @bitCast(f1 * f2);
                    }
                }
                Log.log.debug("types", "matrix multiply cell computed", null);
                result.data[row][col] = @bitCast(sum);
            }
        }
        return result;
    }

    pub fn deinit(self: Matrix, allocator: std.mem.Allocator) void {
        Log.log.debug("types", "matrix deinit", null);
        for (self.data) |row| {
            allocator.free(row);
        }
        allocator.free(self.data);
    }

    pub fn toString(_: Matrix) []const u8 {
        return "matrix";
    }
};
