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
        const full_data = try allocator.alloc([]u64, rows);
        for (full_data) |*row| {
            row.* = try allocator.alloc(u64, cols);
            @memset(row.*, 0);
        }

        var t = MatrixType.Integer;
        if (values) |vs| {
            for (vs) |value| {
                if (std.mem.indexOfScalar(u8, value, '.') != null) {
                    t = MatrixType.Float;
                    break;
                }
            }
            for (vs, 0..) |value, idx| {
                if (idx >= rows * cols) break;
                const row = idx / cols;
                const col = idx % cols;
                full_data[row][col] = if (t == .Float)
                    @bitCast(try std.fmt.parseFloat(f64, value))
                else
                    @bitCast(try std.fmt.parseInt(i64, value, 10));
            }
        }

        return Matrix{
            .rows = rows,
            .cols = cols,
            .data = full_data,
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

    pub fn toString(m: Matrix, allocator: std.mem.Allocator) ![]const u8 {
        var ary: std.ArrayList(u8) = .empty;
        errdefer ary.deinit(allocator);

        for (0..m.rows) |row| {
            try ary.append(allocator, '[');
            for (0..m.cols) |col| {
                if (col != 0) try ary.appendSlice(allocator, ", ");
                if (m.type == .Float) {
                    const f: f64 = @bitCast(m.data[row][col]);
                    const num_str = try std.fmt.allocPrint(allocator, "{d}", .{f});
                    defer allocator.free(num_str);
                    try ary.appendSlice(allocator, num_str);
                } else {
                    const i: i64 = @bitCast(m.data[row][col]);
                    const num_str = try std.fmt.allocPrint(allocator, "{d}", .{i});
                    defer allocator.free(num_str);
                    try ary.appendSlice(allocator, num_str);
                }
            }
            try ary.append(allocator, ']');
            if (row != m.rows - 1) try ary.append(allocator, '\n');
        }

        return ary.toOwnedSlice(allocator);
    }
};
