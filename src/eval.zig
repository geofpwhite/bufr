const std = @import("std");

const Type = @import("types.zig").Type;
const Variable = @import("variable.zig").variable;
const Ast = @import("ast.zig");
pub const state = struct {
    ast: Ast.ast,
    vars: std.StringHashMap(Variable),
    cur_return: ?Variable,
    allocator: std.mem.Allocator,

    const Self = @This();
    pub fn new(tree: Ast.ast, allocator: std.mem.Allocator) Self {
        return Self{
            .ast = tree,
            .vars = std.StringHashMap(Variable).init(std.heap.page_allocator),
            .cur_return = null,
            .allocator = allocator,
        };
    }

    pub fn renew(self: *Self, tree: Ast.ast) void {
        self.ast = tree;
    }

    pub fn Eval(self: *Self) !void {
        if (self.ast.statements) |stmts| for (stmts.items) |stmt| {
            try self.eval(stmt);
        };
    }

    pub fn eval(self: *Self, node: Ast.astNode) !void {
        if (node.value) |v| switch (v) {
            .identifier => |id| {
                try self.eval_identifier(id);
            },
            .digits => |_| {
                try self.eval_digits(v);
            },
            .operator => {},
            .inequality => {},
            .special_token => {},
            .matrix => {},
            .keyword => {},
            .array_operator => {},
        };
    }

    fn eval_digits(self: *Self, num: Ast.astValue) !void {
        self.cur_return = Variable.init(Type.Integer, "", num);
    }

    fn eval_identifier(self: *Self, id: []const u8) !void {
        if (self.vars.get(id)) |v| {
            self.cur_return = v;
        } else {
            self.cur_return = null;
        }
    }
};
