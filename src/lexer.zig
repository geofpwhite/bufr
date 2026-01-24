const std = @import("std");
const operators = @import("operators.zig");
const special_tokens = @import("special_tokens.zig");
pub const token = @import("types.zig").token;

pub const lexer = struct {
    input: []const u8,
    readPosition: usize,
    ch: u8,
    buffer: [1024]u8,
    bufferPosition: usize,

    pub fn new(input: []const u8) lexer {
        return lexer{
            .input = input,
            .readPosition = 0,
            .ch = 0,
            .buffer = [_]u8{0} ** 1024,
            .bufferPosition = 0,
        };
    }

    fn readChar(self: *lexer) bool {
        if (self.readPosition >= self.input.len) {
            self.ch = 0;
            return false;
        }
        self.ch = self.input[self.readPosition];
        self.readPosition += 1;
        return true;
    }

    pub fn tokenize(self: *lexer, allocator: std.mem.Allocator) !std.ArrayList(token) {
        var tokens = std.ArrayList(token).empty;

        while (self.readChar()) {
            const slice: []const u8 = &[_]u8{self.ch};
            const s = special_tokens.SPECIAL_TOKEN_MAP.get(slice);
            const o = operators.OPERATOR_MAP.get(slice);
            const index = std.mem.indexOf(u8, ">=<&|/", slice);
            if ((o != null or s != null) and index == null) {
                if (self.ch == '=') {
                    std.debug.print("Equal sign found\n", .{});
                }
                try self.addCur(&tokens, allocator);
                self.buffer[0] = self.ch;
                self.bufferPosition = 1;
                try self.addCur(&tokens, allocator);
                continue;
            }

            switch (self.ch) {
                '/' => {
                    std.debug.print("Slash found {d}\n", .{tokens.items.len});
                    if (tokens.items.len > 0) {
                        const prev = (tokens.items[tokens.items.len - 1]);
                        if (std.mem.eql(u8, slice, prev)) {
                            allocator.free(prev);
                            _ = tokens.pop();
                            while (self.readPosition < self.input.len and self.input[self.readPosition] != '\n' and self.input[self.readPosition] != '\r') {
                                self.readPosition += 1;
                            }
                            self.readPosition += 1;
                            self.bufferPosition = 0;
                        } else {
                            try self.addCur(&tokens, allocator);
                            self.buffer[0] = self.ch;
                            self.bufferPosition = 1;
                            try self.addCur(&tokens, allocator);
                        }
                    } else {
                        // try self.addCur(&tokens, allocator);
                        self.buffer[0] = self.ch;
                        self.bufferPosition = 1;
                        try self.addCur(&tokens, allocator);
                    }
                },
                ' ', '\n', '\r' => {
                    try self.addCur(&tokens, allocator);
                },

                '|', '&' => {
                    const prev = (tokens.items[tokens.items.len - 1]);
                    if (std.mem.eql(u8, prev, slice)) {
                        allocator.free(prev);
                        const newToken = allocator.alloc(u8, 2) catch unreachable;
                        newToken[0] = self.ch;
                        newToken[1] = self.ch;
                        tokens.items[tokens.items.len - 1] = newToken;
                    } else {
                        try self.addCur(&tokens, allocator);
                        self.buffer[self.bufferPosition] = self.ch;
                        self.bufferPosition += 1;
                        try self.addCur(&tokens, allocator);
                    }
                },

                '<' => {
                    const prev = (tokens.items[tokens.items.len - 1]);
                    if (std.mem.eql(u8, prev, "<")) {
                        allocator.free(prev);
                        const newToken = allocator.dupe(u8, "<<") catch unreachable;
                        tokens.items[tokens.items.len - 1] = newToken;
                    } else {
                        // change prev from "<" to "<="
                        try self.addCur(&tokens, allocator);
                        self.buffer[self.bufferPosition] = self.ch;
                        self.bufferPosition += 1;
                        try self.addCur(&tokens, allocator);
                    }
                },
                '>' => {
                    const prev = (tokens.items[tokens.items.len - 1]);
                    if (std.mem.eql(u8, prev, ">") or std.mem.eql(u8, prev, "<")) {
                        // change prev from ">" to ">="
                        const hold = prev[0];
                        allocator.free(prev);
                        const newToken = try allocator.alloc(u8, 2);
                        newToken[0] = hold;
                        newToken[1] = '>';
                        tokens.items[tokens.items.len - 1] = newToken;
                    } else {
                        try self.addCur(&tokens, allocator);
                        self.buffer[self.bufferPosition] = self.ch;
                        self.bufferPosition += 1;
                        try self.addCur(&tokens, allocator);
                    }
                },
                '=' => {
                    const prev = (tokens.items[tokens.items.len - 1]);
                    if (prev[0] == '=' or prev[0] == '<' or prev[0] == '>') {
                        std.debug.print("Equal sign found\n", .{});

                        // change prev from "=" to "=="
                        const hold = prev[0];
                        allocator.free(prev);
                        const newToken = try allocator.alloc(u8, 2);
                        newToken[0] = hold;
                        newToken[1] = '=';
                        tokens.items[tokens.items.len - 1] = newToken;
                    } else {
                        try self.addCur(&tokens, allocator);
                        self.buffer[self.bufferPosition] = self.ch;
                        self.bufferPosition += 1;
                        try self.addCur(&tokens, allocator);
                    }
                },
                else => {
                    self.buffer[self.bufferPosition] = self.ch;
                    self.bufferPosition += 1;
                },
            }
        }

        try self.addCur(&tokens, allocator);
        return tokens;
    }

    fn addCur(self: *lexer, tokens: *std.ArrayList(token), allocator: std.mem.Allocator) !void {
        if (self.bufferPosition > 0) {
            const n = try allocator.dupe(u8, self.buffer[0..self.bufferPosition]);
            try tokens.append(allocator, n);
            self.bufferPosition = 0;
        }
    }
};

test "lexer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var lex = lexer.new("let x = 12; let y = 14; let z = x + y ;");
    var tokens = try lex.tokenize(allocator);
    defer {
        // free each token slice
        for (tokens.items) |tok| {
            allocator.free(tok);
        }
        tokens.deinit(allocator);
        _ = gpa.deinit();
    }

    for (tokens.items) |tok| {
        std.debug.print("token: {s}\n", .{tok});
    }
    try std.testing.expectEqual(tokens.items.len, 17);
    try std.testing.expectEqualStrings("let", tokens.items[0]);
    try std.testing.expectEqualStrings("x", tokens.items[1]);
}
