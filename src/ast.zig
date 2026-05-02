const std = @import("std");
const Log = @import("log/log.zig");

const operator = @import("operators.zig").Operator;
const inequality = @import("operators.zig").Inequality;
const token = @import("types.zig").token;
const special_token = @import("special_tokens.zig").SpecialToken;
const keyword = @import("keywords.zig").Keyword;
const matrix = @import("types.zig").Matrix;
const matrixType = @import("types.zig").MatrixType;

pub const ast = struct {
    statements: ?std.ArrayList(Node),

    pub fn deinit(self: *ast, allocator: std.mem.Allocator) void {
        if (self.statements) |*stmts| {
            stmts.deinit(allocator);
        }
    }
    pub fn print(self: *ast, allocator: std.mem.Allocator) !void {
        if (self.statements) |statements| {
            for (statements.items) |statement| {
                try statement.print(allocator);
            }
        }
    }
};

pub const Node = struct {
    left: ?*Node,
    right: ?*Node,
    value: ?astValue,
    pub fn print(node: *Node, allocator: std.mem.Allocator) !void {
        if (node.value) |value| {
            const str = try value.toString(allocator);
            Log.log.debug("ast", str, null);
            allocator.free(str);
            if (node.left) |left| {
                Log.log.debug("ast", "left node present", null);
                try left.print(allocator);
            } else {
                Log.log.debug("ast", "left node null", null);
            }
            if (node.right) |right| {
                Log.log.debug("ast", "right node present", null);
                try right.print(allocator);
            } else {
                Log.log.debug("ast", "right node null", null);
            }
        }
    }
    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        if (self.value) |value| {
            switch (value) {
                .matrix => |m| if (m.values) |values| {
                    for (values) |v| {
                        allocator.free(v);
                    }
                    allocator.free(values);
                },
                else => {},
            }
        }
    }
};

pub const matrixValue = struct {
    rows: usize,
    cols: usize,
    elementType: ?matrixType,
    values: ?[]token,
};

pub fn matrixNode(rows: usize, cols: usize) !matrixValue {
    return matrixValue{
        .rows = rows,
        .cols = cols,
        .elementType = matrixType.Float,
        .values = null, // parser needs to scan and populate values
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
