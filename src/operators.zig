const std = @import("std");

pub const Operator = enum {
    Assignment,
    Add,
    Subtract,
    Multiply,
    Divide,
    Modulo,
    Power,
    And,
    Or,
    Not,
    BitAnd,
    BitOr,
    BitXor,
    BitNot,
    BitLShift,
    BitRShift,

    pub fn toString(self: Operator) []const u8 {
        return switch (self) {
            .Assignment => "=",
            .Add => "+",
            .Subtract => "-",
            .Multiply => "*",
            .Divide => "/",
            .Modulo => "%",
            .Power => "^",
            .And => "&",
            .Or => "|",
            .Not => "!",
            .BitAnd => "~",
            .BitOr => "|",
            .BitXor => "^",
            .BitNot => "~",
            .BitLShift => "<<",
            .BitRShift => ">>",
        };
    }
};
pub const ArrayOperator = enum {
    Add,
    pub fn toString(self: ArrayOperator) []const u8 {
        return switch (self) {
            .Add => "+",
        };
    }
};

pub const OPERATOR_MAP = std.StaticStringMap(Operator).initComptime(.{
    .{ "=", .Assignment },
    .{ "+", .Add },
    .{ "-", .Subtract },
    .{ "*", .Multiply },
    .{ "/", .Divide },
    .{ "%", .Modulo },
    .{ "^", .Power },
    .{ "&", .BitAnd },
    .{ "|", .BitOr },
    .{ "!", .Not },
    .{ "~", .BitNot },
    .{ "<<", .BitLShift },
    .{ ">>", .BitRShift },
    .{ "&&", .And },
    .{ "||", .Or },
});

pub const OPERATOR_PRECEDENCE = std.StaticStringMap(u8).initComptime(.{
    .{ "+", 1 },
    .{ "-", 1 },
    .{ "*", 2 },
    .{ "/", 2 },
    .{ "%", 2 },
    .{ "^", 3 },
    .{ "&", 4 },
    .{ "|", 4 },
    .{ "~", 4 },
    .{ "<<", 5 },
    .{ ">>", 5 },
    .{ "&&", 5 },
    .{ "!", 5 },
    .{ "||", 5 },
});

pub const Inequality = enum {
    LessThan,
    GreaterThan,
    LessThanOrEqual,
    GreaterThanOrEqual,
    Equals,
    NotEquals,
    pub fn toString(self: Inequality) []const u8 {
        return switch (self) {
            .LessThan => "<",
            .GreaterThan => ">",
            .LessThanOrEqual => "<=",
            .GreaterThanOrEqual => ">=",
            .Equals => "==",
            .NotEquals => "!=",
        };
    }
};

pub const INEQUALITY_MAP = std.StaticStringMap(Inequality).initComptime(.{
    .{ "<", .LessThan },
    .{ ">", .GreaterThan },
    .{ "<=", .LessThanOrEqual },
    .{ ">=", .GreaterThanOrEqual },
    .{ "==", .Equals },
    .{ "!=", .NotEquals },
});
