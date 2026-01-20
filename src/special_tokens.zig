const std = @import("std");

pub const SpecialToken = enum {
    Lparen,
    Rparen,
    Lsquare,
    Rsquare,
    Dot,
    Lcurly,
    Rcurly,
    Colon,
    Semicolon,
    Comment,

    pub fn toString(self: SpecialToken) []const u8 {
        return switch (self) {
            .Lparen => "(",
            .Rparen => ")",
            .Lsquare => "[",
            .Rsquare => "]",
            .Dot => ".",
            .Lcurly => "{",
            .Rcurly => "}",
            .Colon => ":",
            .Semicolon => ";",
            .Comment => "//",
        };
    }
};

pub const SPECIAL_TOKEN_MAP = std.StaticStringMap(SpecialToken).initComptime(.{
    .{ "(", .Lparen },
    .{ ")", .Rparen },
    .{ "[", .Lsquare },
    .{ "]", .Rsquare },
    .{ ".", .Dot },
    .{ "{", .Lcurly },
    .{ "}", .Rcurly },
    .{ ":", .Colon },
    .{ ";", .Semicolon },
    .{ "//", .Comment },
});
