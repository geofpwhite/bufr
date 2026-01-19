const std = @import("std");

pub const Keyword = enum {
    For,
    If,
    While,
    Else,
    Return,
    Break,
    Continue,
    Fn,
    Let,

    pub fn toString(self: Keyword) []const u8 {
        return switch (self) {
            .For => "for",
            .If => "if",
            .While => "while",
            .Else => "else",
            .Return => "return",
            .Break => "break",
            .Continue => "continue",
            .Fn => "fn",
            .Let => "let",
        };
    }
};

pub const KEYWORD_MAP = std.StaticStringMap(Keyword).initComptime(.{
    .{ "for", .For },
    .{ "if", .If },
    .{ "while", .While },
    .{ "else", .Else },
    .{ "return", .Return },
    .{ "break", .Break },
    .{ "continue", .Continue },
    .{ "fn", .Fn },
    .{ "let", .Let },
});
