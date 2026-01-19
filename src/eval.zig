const std = @import("std");

const Type = @import("types.zig").Type;
const Variable = @import("variable.zig").variable;
const ast = @import("ast.zig").ast;
pub const state = struct {
    ast: ast,
    vars: std.StringHashMap(Variable),

    const Self = @This();
    pub fn new(tree: ast) Self {
        return Self{
            .ast = tree,
            .vars = std.StringHashMap(Variable).init(std.heap.page_allocator),
        };
    }

    pub fn renew(self: *Self, tree: ast) void {
        self.ast = tree;
    }

    pub fn Eval(self: *Self) !void {
        _ = self;
    }
};
