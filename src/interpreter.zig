const std = @import("std");

const Ast = @import("ast.zig");
const Lexer = @import("lexer.zig").lexer;
const Parser = @import("parser.zig").parser;
const State = @import("eval.zig").state;
const Token = @import("types.zig").token;
const Operator = @import("operators.zig").Operator;

pub fn execute(path: []const u8, allocator: std.mem.Allocator) !void {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024 * 1024); // 1GB max size
    defer allocator.free(file_contents);
    var lexer = Lexer.new(file_contents);
    var tokens = try lexer.tokenize(allocator);
    const items = tokens.items;
    var parser = Parser.new(items, allocator);
    var tree = try parser.Parse();
    var eval = State.new(tree, allocator);
    try eval.Eval();

    defer {
        // free each token slice
        for (tokens.items) |tok| {
            allocator.free(tok);
        }
        tokens.deinit(allocator);
        tree.deinit(allocator);
        parser.deinit();
        eval.deinit();
    }
    var iter = eval.vars.keyIterator();
    while (iter.next()) |k| {
        std.debug.print("{any} = {any}\n", .{ k, eval.vars.get(k.*) });
    }
}

test "lex and parse" {
    const eql = @intFromEnum(Operator.Add) > @intFromEnum(Operator.Subtract);
    std.debug.print("Operator precedence: {any}\n", .{eql});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const input = "let x = 6x6;";
    var lexer = Lexer.new(input);
    var tokens = try lexer.tokenize(allocator);
    var parser = Parser.new(tokens.items, allocator);
    var ast = try parser.Parse();
    defer {
        // free each token slice
        for (tokens.items) |tok| {
            allocator.free(tok);
        }
        tokens.deinit(allocator);
        ast.deinit(allocator);
        parser.deinit();
        _ = gpa.deinit();
    }
    if (ast.statements) |stmts| {
        std.debug.print("AST: {any}\n", .{stmts.items[0]});
        for (stmts.items) |stmt| {
            var s = stmt;
            if (stmt.value) |_| {
                try s.print(allocator);
            }
        }
    }
    // try std.testing.expect(ast.len == 1);
}

test "exec" {
    try execute("./bufr_code/nums.bufr", std.testing.allocator);
}
