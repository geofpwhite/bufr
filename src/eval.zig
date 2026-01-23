const std = @import("std");

const Type = @import("types.zig").Type;
const Variable = @import("variable.zig").variable;
const Matrix = @import("types.zig").Matrix;
const MatrixType = @import("types.zig").MatrixType;
const Inequality = @import("operators.zig").Inequality;
const SpecialToken = @import("special_tokens.zig").SpecialToken;
const Keyword = @import("keywords.zig").Keyword;
const Operators = @import("operators.zig");
const Operator = @import("operators.zig").Operator;
const Ast = @import("ast.zig");
const evalError = error{
    NullValueUsed,
    SyntaxError,
    TypeMismatch,
    UndefinedVariable,
    InvalidType,
};

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

    pub fn deinit(self: *Self) void {
        self.vars.deinit();
    }

    pub fn Eval(self: *Self) !void {
        if (self.ast.statements) |stmts| for (stmts.items) |stmt| {
            try self.eval(stmt);
        };
    }

    pub fn eval(self: *Self, node: Ast.astNode) evalError!void {
        if (node.value) |v| switch (v) {
            .identifier => |id| {
                try self.eval_identifier(id);
            },
            .integer => |_| {
                self.eval_int(v) catch {
                    return evalError.InvalidType;
                };
            },
            .float => |_| {
                self.eval_float(v) catch {
                    return evalError.InvalidType;
                };
            },
            .operator => |op| self.eval_operator(node, op) catch {
                return evalError.InvalidType;
            },
            .inequality => |ineq| try self.eval_inequality(node, ineq),
            .special_token => |sp| try self.eval_special_token(node, sp),
            .matrix => |mat| try self.eval_matrix(mat),
            .keyword => |kw| try self.eval_keyword(node, kw),
            .boolean => |b| try self.eval_boolean(b),
        };
    }

    fn eval_int(self: *Self, num: Ast.astValue) !void {
        self.cur_return = try Variable.init(self.allocator, Type.Integer, "", num);
    }
    fn eval_float(self: *Self, num: Ast.astValue) !void {
        self.cur_return = try Variable.init(self.allocator, Type.Float, "", num);
    }

    fn eval_identifier(self: *Self, id: []const u8) !void {
        if (self.vars.get(id)) |v| {
            self.cur_return = v;
        } else {
            self.cur_return = null;
        }
    }

    fn eval_operator(self: *Self, node: Ast.astNode, op: Operator) !void {
        switch (op) {
            .Assignment => {
                try self.eval_assignment(node);
            },
            else => {
                if (node.left) |left| if (node.right) |right| {
                    try self.eval(left.*);
                    const leftValue = self.cur_return;
                    try self.eval(right.*);
                    const rightValue = self.cur_return;
                    if (leftValue) |l| if (rightValue) |r| {
                        switch (op) {
                            .Assignment => return evalError.SyntaxError,
                            else => try self.operate(l, r, op),
                        }
                    } else return evalError.NullValueUsed;
                };
            },
        }
    }

    fn eval_assignment(self: *Self, node: Ast.astNode) !void {
        if (node.left) |left| if (left.value) |value| {
            switch (value) {
                .identifier => |name| if (node.right) |right| {
                    if (self.vars.get(name)) |_| {
                        try self.eval(right.*);
                        if (self.cur_return) |cr| {
                            try self.vars.put(name, cr);
                        }
                    } else {
                        return evalError.UndefinedVariable;
                    }
                },
                .keyword => |kw| if (kw == .Let) if (node.right) |right| {
                    try self.eval(right.*);
                    if (self.cur_return) |cr| {
                        if (left.right) |left_right| {
                            std.debug.print("left.right = {any}\n", .{left_right});
                            std.debug.print("right = {any}\n", .{right});
                            try self.vars.put(left_right.value.?.identifier, cr);
                        } else {
                            if (self.vars.get("y")) |y| {
                                std.debug.print("var: {any}\n", .{y});
                            }
                            return evalError.SyntaxError;
                        }
                    }
                } else {
                    return evalError.SyntaxError;
                },
                else => {
                    return evalError.SyntaxError;
                },
            }
        } else return evalError.SyntaxError;
    }

    fn eval_inequality(self: *Self, node: Ast.astNode, ineq: Inequality) !void {
        if (node.left) |l| if (node.right) |r| {
            try self.eval(l.*);
            const left = self.cur_return.?;
            try self.eval(r.*);
            const right = self.cur_return.?;
            try self.inequality(left, right, ineq);
        } else return evalError.SyntaxError;
    }

    fn eval_special_token(self: *Self, node: Ast.astNode, sp: SpecialToken) !void {
        if (node.left) |l| if (node.right) |r| {
            try self.eval(l.*);
            const left = self.cur_return.?;

            try self.eval(r.*);
            const right = self.cur_return.?;
            try self.special_token(left, right, sp);
        } else {
            return evalError.SyntaxError;
        };
    }

    fn eval_matrix(self: *Self, mat: Ast.matrixValue) !void {
        self.cur_return = Variable{
            .name = "",
            .type = Type.Matrix,
            .data = .{
                .matrix = Matrix.new(
                    self.allocator,
                    mat.rows,
                    mat.cols,
                    if (mat.elementType) |t| t else MatrixType.Float,
                ) catch {
                    return evalError.SyntaxError;
                },
            },
        };
    }
    fn eval_boolean(self: *Self, b: bool) !void {
        self.cur_return = Variable{
            .name = "",
            .type = Type.Bool,
            .data = .{
                .boolean = b,
            },
        };
    }

    fn eval_keyword(self: *Self, node: Ast.astNode, kw: Keyword) !void {
        _ = self;
        _ = node;
        switch (kw) {
            // .For => "for",
            // .If => "if",
            // .While => "while",
            // .Else => "else",
            // .Return => "return",
            // .Break => "break",
            // .Continue => "continue",
            // .Fn => "fn",
            .Let => return evalError.SyntaxError,
            else => {},
        }
    }

    fn special_token(self: *Self, left: Variable, right: Variable, sp: SpecialToken) !void {
        _ = self;
        _ = left;
        _ = right;
        _ = sp;
        // try self.eval(left);
        // const left = self.cur_return.?;

        // try self.eval(right);
        // const right = self.cur_return.?;

        // self.cur_return = try self.special_token(left, right, sp);
    }

    fn inequality(self: *Self, left: Variable, right: Variable, ineq: Inequality) !void {
        self.cur_return = Variable{
            .name = "",
            .type = .Bool,
            .data = .{ .boolean = false },
        };
        if (left.type != right.type) {
            return evalError.TypeMismatch;
        }
        switch (ineq) {
            .Equals => {
                if (left.type == right.type) {
                    switch (left.type) {
                        .Integer => |_| {
                            const l_int = left.data.integer;
                            const r_int = right.data.integer;
                            self.cur_return = .{
                                .name = "",
                                .data = .{ .boolean = l_int == r_int },
                                .type = .Bool,
                            };
                        },
                        .Float => |_| {
                            const l_float = left.data.float;
                            const r_float = right.data.float;
                            self.cur_return = .{
                                .name = "",
                                .data = .{ .boolean = l_float == r_float },
                                .type = .Bool,
                            };
                        },
                        .Matrix => |_| {
                            const l_matrix = left.data.matrix;
                            const r_matrix = right.data.matrix;
                            self.cur_return = .{
                                .name = "",
                                .data = .{ .boolean = Matrix.eql(l_matrix, r_matrix) },
                                .type = .Bool,
                            };
                        },
                        .Bool => |_| {
                            const l_bool = left.data.boolean;
                            const r_bool = right.data.boolean;
                            self.cur_return = .{
                                .name = "",
                                .data = .{ .boolean = l_bool == r_bool },
                                .type = .Bool,
                            };
                        },
                        .NULL => |_| {
                            self.cur_return = .{
                                .name = "",
                                .data = .{ .boolean = true },
                                .type = .Bool,
                            };
                        },
                    }
                }
            },
            .LessThan => {},
            .GreaterThan => {},
            .LessThanOrEqual => {},
            .GreaterThanOrEqual => {},
            .NotEquals => {},
        }
    }

    fn operate(self: *Self, left: Variable, right: Variable, operator: Operator) !void {
        if (left.type != right.type) {
            return evalError.TypeMismatch;
        }
        switch (operator) {
            .Add => {
                switch (left.type) {
                    .Integer => |_| {
                        const l_int = left.data.integer;
                        const r_int = right.data.integer;
                        self.cur_return = Variable{
                            .name = "",
                            .type = .Integer,
                            .data = .{ .integer = l_int + r_int },
                        };
                    },
                    .Float => |_| {
                        const l_float = left.data.float;
                        const r_float = right.data.float;
                        self.cur_return = Variable{
                            .name = "",
                            .type = .Float,
                            .data = .{ .float = l_float + r_float },
                        };
                    },
                    .Matrix => {
                        self.cur_return = Variable{
                            .name = "",
                            .type = .Matrix,
                            .data = .{ .matrix = try Matrix.add(self.allocator, left.data.matrix, right.data.matrix) },
                        };
                    },
                    else => return evalError.TypeMismatch,
                }
            },

            // .Subtract => "-",
            // .Multiply => "*",
            // .Divide => "/",
            // .Modulo => "%",
            // .Power => "^",
            // .And => "&",
            // .Or => "|",
            // .Not => "!",
            // .BitAnd => "~",
            // .BitOr => "|",
            // .BitXor => "^",
            // .BitNot => "~",
            // .BitLShift => "<<",
            // .BitRShift => ">>",
            else => return evalError.SyntaxError,
        }
    }
};
