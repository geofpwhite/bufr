const std = @import("std");

const keyword = @import("keywords.zig").Keyword;
const KEYWORD_MAP = @import("keywords.zig").KEYWORD_MAP;
const operator = @import("operators.zig").Operator;
const OPERATOR_MAP = @import("operators.zig").OPERATOR_MAP;
const inequality = @import("operators.zig").Inequality;
const INEQUALITY_MAP = @import("operators.zig").INEQUALITY_MAP;
const SPECIAL_TOKEN_MAP = @import("special_tokens.zig").SPECIAL_TOKEN_MAP;
const special_token = @import("special_tokens.zig").SpecialToken;
const lexer = @import("lexer.zig");
const token = lexer.token;
const Ast = @import("ast.zig");
const ast = Ast.ast;
const Type = @import("types.zig").Type;

const parserError = error{
    RootKeyword,
    RootOperator,
    AllocFailed,
    InvalidToken,
};

pub const parser = struct {
    input: [][]const u8,
    references: std.ArrayList(*Ast.astNode),
    statements: ast,
    allocator: std.mem.Allocator,
    pub fn new(input: [][]const u8, allocator: std.mem.Allocator) parser {
        return parser{
            .input = input,
            .references = std.ArrayList(*Ast.astNode).empty,
            .statements = ast{ .statements = null },
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *parser) void {
        for (self.references.items) |ref| {
            self.allocator.destroy(ref);
        }
        self.references.deinit(self.allocator);
    }
    fn parse_expression(self: *parser, root: bool, cur: Ast.astNode, index: usize, expression: token) parserError!ast {
        const newNode = self.allocator.create(Ast.astNode) catch {
            return parserError.AllocFailed;
        };
        newNode.* = Ast.astNode{
            .value = .{ .identifier = expression },
            .left = null,
            .right = null,
        };
        self.references.append(self.allocator, newNode) catch {
            return parserError.AllocFailed;
        };

        const id = expression;

        if (std.fmt.parseInt(i64, id, 10)) |n| {
            newNode.*.value = .{ .integer = n };
            if (self.input.len > index + 2 and self.input[index + 1][0] == '.' and self.input[index + 2][0] >= '0' and self.input[index + 2][0] <= '9') {
                const float_string = std.mem.concat(self.allocator, u8, &.{ expression, ".", self.input[index + 2] }) catch {
                    return parserError.AllocFailed;
                };
                defer self.allocator.free(float_string);
                if (std.fmt.parseFloat(f64, float_string)) |f| {
                    newNode.*.value = .{ .float = f };
                } else |_| {}
            }
        } else |_| {}
        if (cur.value) |v| {
            if (v == .keyword) {
                const kw = v.keyword;
                if (kw == .Let) {
                    var newCur = cur;
                    newCur.right = newNode;
                    return self.parse(root, newCur, index);
                }
            }
        }
        var new_index = index;
        if (newNode.value) |value| if (value == .float) {
            new_index += 2;
        };
        if (root) {
            if (cur.right) |right|
                if (right.value) |val|
                    if (val == .operator) {
                        var newCur = cur;
                        newCur.right.?.right = newNode;
                        return self.parse(root, newCur, new_index);
                    };
            var newCur = cur;
            newCur.right = newNode;
            return self.parse(root, newCur, new_index);
        } else {
            if (cur.value) |val| switch (val) {
                .keyword => {
                    var newCur = cur;
                    newCur.right = newNode;
                    return self.parse(root, newCur, new_index);
                },
                .operator => {
                    var newCur = cur;
                    newCur.right = newNode;
                    return self.parse(root, newCur, new_index);
                },
                else => {},
            };
            return self.parse(root, newNode.*, new_index);
        }
    }
    fn parse_special_token(self: *parser, root: bool, cur: Ast.astNode, index: usize, sToken: special_token) parserError!ast {
        const newNode = self.allocator.create(Ast.astNode) catch {
            return parserError.AllocFailed;
        };
        newNode.* = Ast.astNode{
            .value = .{ .special_token = sToken },
            .left = null,
            .right = null,
        };
        self.references.append(self.allocator, newNode) catch {
            return parserError.AllocFailed;
        };
        switch (sToken) {
            special_token.Colon => {},
            special_token.Lcurly => {},
            special_token.Lparen => {},
            special_token.Lsquare => {},
            special_token.Rcurly => {},
            special_token.Rparen => {},
            special_token.Rsquare => {},
            special_token.Dot => {},
            special_token.Semicolon => {
                if (self.statements.statements == null) {
                    self.statements.statements = std.ArrayList(Ast.astNode).empty;
                }
                self.allocNewStatement(cur) catch {
                    return parserError.AllocFailed;
                };
                return self.parse(false, Ast.astNode{ .left = null, .right = null, .value = null }, index);
            },
            special_token.Comment => {},
        }
        return self.parse(root, newNode.*, index);
    }

    fn allocNewStatement(self: *parser, cur: Ast.astNode) !void {
        if (self.statements.statements == null) {
            self.statements = .{ .statements = std.ArrayList(Ast.astNode).empty };
        }
        try self.statements.statements.?.append(self.allocator, cur);
    }

    fn parse_keyword(self: *parser, root: bool, cur: Ast.astNode, index: usize, kw: keyword) parserError!ast {
        if (root) {
            return parserError.RootKeyword;
        }
        const newNode = self.allocator.create(Ast.astNode) catch {
            return parserError.AllocFailed;
        };
        newNode.* = Ast.astNode{
            .value = .{ .keyword = kw },
            .left = null,
            .right = null,
        };
        self.references.append(self.allocator, newNode) catch {
            return parserError.AllocFailed;
        };
        switch (kw) {
            keyword.For => {},
            keyword.If => {},
            keyword.While => {},
            keyword.Else => {},
            keyword.Return => {},
            keyword.Break => {},
            keyword.Continue => {},
            keyword.Fn => {},
            keyword.Let => {
                return self.parse(root, newNode.*, index);
            },
        }
        if (root) {
            var newCur = cur;

            newCur.right = newNode;

            return self.parse(root, newCur, index);
        } else {
            return self.parse(true, newNode.*, index);
        }
    }

    fn parse_operator(self: *parser, root: bool, cur: Ast.astNode, index: usize, op: operator) parserError!ast {
        var newNode = self.allocator.create(Ast.astNode) catch {
            return parserError.AllocFailed;
        };
        newNode.* = Ast.astNode{
            .value = .{ .operator = op },
            .left = null,
            .right = null,
        };
        self.references.append(self.allocator, newNode) catch {
            return parserError.AllocFailed;
        };
        var newCur = cur;
        switch (op) {
            operator.Assignment => {
                newNode.left = &newCur;
                return self.parse(true, newNode.*, index);
            },
            operator.Not, operator.BitNot => {
                if (root) {
                    if (cur.right) |right| {
                        if (right.value) |val| if (val == .operator) {
                            newCur.right.?.right = newNode;
                            return self.parse(root, newCur, index);
                        };
                    } else {
                        newCur.right = newNode;
                        return self.parse(root, newCur, index);
                    }
                } else {
                    if (cur.value) |val| {
                        if (val == .operator) {
                            newCur.right = newNode;
                            return self.parse(root, newCur, index);
                        }
                    }
                    newNode.left = &newCur;
                    return self.parse(root, newNode.*, index);
                }
            },
            else => {
                if (root) {
                    newNode.left = newCur.right;
                    newCur.right = newNode;
                } else {
                    newNode.left = &newCur;
                    newCur = newNode.*;
                }
                return self.parse(root, newCur, index);
            },
        }
        return self.parse(root, newCur, index);
    }
    fn parse_inequality(self: *parser, root: bool, cur: Ast.astNode, index: usize, ineq: inequality) parserError!ast {
        var newNode = self.allocator.create(Ast.astNode) catch {
            return parserError.AllocFailed;
        };
        newNode.* = Ast.astNode{
            .value = .{ .inequality = ineq },
            .left = null,
            .right = null,
        };
        self.references.append(self.allocator, newNode) catch {
            return parserError.AllocFailed;
        };

        var newCur = cur;
        if (root) {
            newNode.left.? = newCur.right.?;
            newCur.right.? = newNode;
        } else {
            newNode.left.?.* = newCur;
            newCur = newNode.*;
        }
        return self.parse(root, newCur, index);
    }
    pub fn parse_matrix(self: *parser, root: bool, cur: Ast.astNode, index: usize) parserError!ast {
        const cur_token = self.input[index];
        const newNode = self.allocator.create(Ast.astNode) catch {
            return parserError.AllocFailed;
        };
        const index_x = std.mem.indexOf(u8, cur_token, "x");
        self.references.append(self.allocator, newNode) catch {
            return parserError.AllocFailed;
        };
        var before_x: usize = 0;
        var after_x: usize = 0;
        if (index_x) |x_index| {
            before_x = std.fmt.parseInt(usize, cur_token[0..x_index], 10) catch {
                return parserError.AllocFailed;
            };
            after_x = std.fmt.parseInt(usize, cur_token[x_index + 1 ..], 10) catch {
                return parserError.AllocFailed;
            };
        }
        newNode.* = Ast.astNode{
            .value = .{ .matrix = Ast.matrixNode(before_x, after_x) catch {
                return parserError.AllocFailed;
            } },
            .left = null,
            .right = null,
        };
        var newCur = cur;
        newCur = cur;
        return self.parse(root, newCur, index);
    }

    pub fn Parse(self: *parser) parserError!ast {
        return self.parse(false, Ast.astNode{ .left = null, .right = null, .value = null }, 0);
    }
    fn parse(self: *parser, root: bool, cur: Ast.astNode, index: usize) parserError!ast {
        if (index >= self.input.len) {
            return self.statements;
        }
        std.debug.print("Current Token: {s}\n", .{self.input[index]});
        std.debug.print("Current Node: {any}\n", .{cur});
        const cur_token = self.input[index];
        const new_index = index + 1;
        const kword = KEYWORD_MAP.get(cur_token);
        if (kword) |kw| {
            return self.parse_keyword(root, cur, new_index, kw);
        }
        const op = OPERATOR_MAP.get(cur_token);
        if (op) |opp| {
            std.debug.print("Operator: {any}\n", .{opp});
            return self.parse_operator(root, cur, new_index, opp);
        }
        const ineq = INEQUALITY_MAP.get(cur_token);
        if (ineq) |inq| {
            return self.parse_inequality(root, cur, new_index, inq);
        }

        const special = SPECIAL_TOKEN_MAP.get(cur_token);
        if (special) |spec| {
            return self.parse_special_token(root, cur, new_index, spec);
        }
        if (try self.scan_for_matrix_init(index)) {
            return self.parse_matrix(root, cur, new_index);
        }

        return self.parse_expression(root, cur, new_index, cur_token);
    }

    fn scan_for_matrix_init(self: *parser, index: usize) parserError!bool {
        var check_index: usize = 0;
        const check = self.input[index];
        while (check_index < check.len and ('0' <= check[check_index] and check[check_index] <= '9')) {
            check_index += 1;
        }
        if (0 < check_index and check_index < check.len and check[check_index] == 'x') {
            return true;
        }
        return false;
    }
};
