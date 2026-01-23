const std = @import("std");

const operator = @import("operators.zig").Operator;
const inequality = @import("operators.zig").Inequality;
const token = @import("types.zig").token;
const special_token = @import("special_tokens.zig").SpecialToken;
const keyword = @import("keywords.zig").Keyword;
const matrix = @import("types.zig").Matrix;
const matrixType = @import("types.zig").MatrixType;

pub const ast = struct {
    statements: ?std.ArrayList(astNode),

    pub fn deinit(self: *ast, allocator: std.mem.Allocator) void {
        self.statements.?.deinit(allocator);
    }
    pub fn print(self: *ast, allocator: std.mem.Allocator) !void {
        if (self.statements) |statements| {
            for (statements.items) |statement| {
                try statement.print(allocator);
            }
        }
    }
};

pub const astNode = struct {
    left: ?*astNode,
    right: ?*astNode,
    value: ?astValue,
    pub fn print(node: *astNode, allocator: std.mem.Allocator) !void {
        if (node.value) |value| {
            const str = try value.toString(allocator);
            std.debug.print("Node: {s}\n", .{str});
            allocator.free(str);
            if (node.left) |left| {
                std.debug.print("left: {any}\n", .{left});
                try left.print(allocator);
            } else {
                std.debug.print("Left: {any}\n", .{node.left});
            }
            if (node.right) |right| {
                std.debug.print("right: {any}\n", .{right});
                try right.print(allocator);
            } else {
                std.debug.print("Right: {any}\n", .{node.right});
            }
        }
    }
};

pub const matrixValue = struct {
    rows: usize,
    cols: usize,
    elementType: ?matrixType,
};

pub fn matrixNode(rows: usize, cols: usize) !matrixValue {
    return matrixValue{
        .rows = rows,
        .cols = cols,
        .elementType = null,
    };
}

pub const astValue = union(enum) {
    identifier: token,
    integer: i64,
    float: f64,
    boolean: bool,
    operator: operator,
    inequality: inequality,
    special_token: special_token,
    matrix: matrixValue,
    keyword: keyword,

    pub fn toString(self: astValue, allocator: std.mem.Allocator) ![]u8 {
        switch (self) {
            .identifier => |id| return try std.fmt.allocPrint(allocator, "{s}", .{id}),
            .integer => |num| return try std.fmt.allocPrint(allocator, "{d}", .{num}),
            .operator => |op| return try std.fmt.allocPrint(allocator, "{s}", .{op.toString()}),
            .inequality => |ineq| return try std.fmt.allocPrint(allocator, "{s}", .{ineq.toString()}),
            .float => |f| return try std.fmt.allocPrint(allocator, "{any}", .{f}),
            .special_token => |special| return try std.fmt.allocPrint(allocator, "{s}", .{special.toString()}),
            .keyword => |kword| return try std.fmt.allocPrint(allocator, "{s}", .{kword.toString()}),
            .boolean => |b| return try std.fmt.allocPrint(allocator, "{any}", .{b}),
            .matrix => |mat| return try std.fmt.allocPrint(allocator, "{any}", .{mat}),
        }
    }
};
