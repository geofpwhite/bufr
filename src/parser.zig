const std = @import("std");
const Log = @import("log/log.zig");

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
    references: std.ArrayList(*Ast.Node),
    statements: ast,
    allocator: std.mem.Allocator,
    pub fn new(input: [][]const u8, allocator: std.mem.Allocator) parser {
        return parser{
            .input = input,
            .references = std.ArrayList(*Ast.Node).empty,
            .statements = ast{ .statements = null },
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *parser) void {
        for (self.references.items) |ref| {
            ref.deinit(self.allocator);
            self.allocator.destroy(ref);
        }
        self.references.deinit(self.allocator);
    }
    fn parse_expression(self: *parser, root: bool, cur: *Ast.Node, index: usize, expression: token) parserError!ast {
        const newNode = self.allocator.create(Ast.Node) catch {
            return parserError.AllocFailed;
        };
        newNode.* = Ast.Node{
            .value = .{ .identifier = expression },
            .left = null,
            .right = null,
        };
        self.references.append(self.allocator, newNode) catch {
            return parserError.AllocFailed;
        };

        const id = expression;

        if (std.fmt.parseInt(i64, id, 10)) |n| {
            Log.log.debug(
                "parser",
                "integer parsed",
                &[_]Log.Field{.{ .key = "int parsed", .value = id }},
            );
            newNode.*.value = .{ .integer = n };
            if (self.input.len > index + 1 and self.input[index][0] == '.' and self.input[index + 1][0] >= '0' and self.input[index + 1][0] <= '9') {
                const float_string = std.mem.concat(self.allocator, u8, &.{ expression, ".", self.input[index + 1] }) catch {
                    return parserError.AllocFailed;
                };
                defer self.allocator.free(float_string);
                Log.log.debug("parser", "float parsed", null);
                if (std.fmt.parseFloat(f64, float_string)) |f| {
                    newNode.*.value = .{ .float = f };
                } else |_| {}
            }
        } else |_| {}
        if (cur.value) |v| {
            if (v == .keyword) {
                const kw = v.keyword;
                if (kw == .Let) {
                    cur.right = newNode;
                    return self.parse(root, cur, index);
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
                        cur.right.?.right = newNode;
                        return self.parse(root, cur, new_index);
                    };
            cur.right = newNode;
            return self.parse(root, cur, new_index);
        } else {
            if (cur.value) |val| switch (val) {
                .keyword => {
                    cur.right = newNode;
                    return self.parse(root, cur, new_index);
                },
                .operator => {
                    cur.right = newNode;
                    return self.parse(root, cur, new_index);
                },
                else => {},
            };
            return self.parse(root, newNode, new_index);
        }
    }
    fn parse_special_token(self: *parser, root: bool, cur: *Ast.Node, index: usize, sToken: special_token) parserError!ast {
        const newNode = self.allocator.create(Ast.Node) catch {
            return parserError.AllocFailed;
        };
        newNode.* = Ast.Node{
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
            special_token.Dot => {
                if (root) {
                    newNode.left = cur.right;
                    cur.right = newNode;
                    Log.log.debug("parser", "dot token root found", null);
                } else {
                    newNode.left = cur;
                    cur.* = newNode.*;
                    Log.log.debug("parser", "dot token found", null);
                }
                return self.parse(root, cur, index);
            },
            special_token.Semicolon => {
                if (self.statements.statements == null) {
                    self.statements.statements = std.ArrayList(Ast.Node).empty;
                }
                self.allocNewStatement(cur) catch {
                    return parserError.AllocFailed;
                };
                var new_statement = Ast.Node{ .left = null, .right = null, .value = null };
                return self.parse(false, &new_statement, index);
            },
            special_token.Comment => {},
        }
        return self.parse(root, newNode, index);
    }

    fn allocNewStatement(self: *parser, cur: *Ast.Node) !void {
        if (self.statements.statements == null) {
            self.statements = .{ .statements = std.ArrayList(Ast.Node).empty };
        }
        try self.statements.statements.?.append(self.allocator, cur.*);
    }

    fn parse_keyword(self: *parser, root: bool, cur: *Ast.Node, index: usize, kw: keyword) parserError!ast {
        if (root) {
            return parserError.RootKeyword;
        }
        Log.log.debug("parser", "keyword scanned", null);
        const newNode = self.allocator.create(Ast.Node) catch {
            return parserError.AllocFailed;
        };
        newNode.* = Ast.Node{
            .value = .{ .keyword = kw },
            .left = null,
            .right = null,
        };
        self.references.append(self.allocator, newNode) catch {
            return parserError.AllocFailed;
        };
        switch (kw) {
            .For => {},
            .If => {},
            .While => {},
            .Else => {},
            .Return => {},
            .Break => {},
            .Continue => {},
            .Fn => {},
            .Let => {
                return self.parse(root, newNode, index);
            },
            .Print => {
                //return
            },
        }
        if (root) {
            cur.right = newNode;
            return self.parse(root, cur, index);
        } else {
            return self.parse(true, newNode, index);
        }
    }

    fn parse_operator(self: *parser, root: bool, cur: *Ast.Node, index: usize, op: operator) parserError!ast {
        var newNode = self.allocator.create(Ast.Node) catch {
            return parserError.AllocFailed;
        };
        newNode.* = Ast.Node{
            .value = .{ .operator = op },
            .left = null,
            .right = null,
        };
        self.references.append(self.allocator, newNode) catch {
            return parserError.AllocFailed;
        };
        switch (op) {
            operator.Assignment => {
                newNode.left = cur;
                return self.parse(true, newNode, index);
            },
            operator.Not, operator.BitNot => {
                if (root) {
                    if (cur.right) |right| {
                        if (right.value) |val| if (val == .operator) {
                            cur.right.?.right = newNode;
                            return self.parse(root, cur, index);
                        };
                    } else {
                        cur.right = newNode;
                        return self.parse(root, cur, index);
                    }
                } else {
                    if (cur.value) |val| {
                        if (val == .operator) {
                            cur.right = newNode;
                            return self.parse(root, cur, index);
                        }
                    }
                    newNode.left = cur;
                    return self.parse(root, newNode, index);
                }
            },
            else => {
                if (root) {
                    newNode.left = cur.right;
                    cur.right = newNode;
                } else {
                    newNode.left = cur;
                    cur.* = newNode.*;
                }
                return self.parse(root, cur, index);
            },
        }
        return self.parse(root, cur, index);
    }
    fn parse_inequality(self: *parser, root: bool, cur: *Ast.Node, index: usize, ineq: inequality) parserError!ast {
        var newNode = self.allocator.create(Ast.Node) catch {
            return parserError.AllocFailed;
        };
        newNode.* = Ast.Node{
            .value = .{ .inequality = ineq },
            .left = null,
            .right = null,
        };
        self.references.append(self.allocator, newNode) catch {
            return parserError.AllocFailed;
        };

        if (root) {
            newNode.left = cur.right;
            cur.right = newNode;
        } else {
            newNode.left = cur;
            cur.* = newNode.*;
        }
        return self.parse(root, cur, index);
    }
    fn parse_matrix(self: *parser, root: bool, cur: *Ast.Node, index: usize, cur_token: []const u8) parserError!ast {
        const newNode = self.allocator.create(Ast.Node) catch {
            return parserError.AllocFailed;
        };
        const index_x = std.mem.indexOf(u8, cur_token, "x");
        Log.log.debug("parser", "scanning matrix init token", null);
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
            newNode.* = Ast.Node{
                .value = .{ .matrix = Ast.matrixNode(before_x, after_x) catch {
                    return parserError.AllocFailed;
                } },
                .left = null,
                .right = null,
            };
            var next_index = index;
            if (self.input[index].len == 1 and self.input[index][0] == '{') {
                while (next_index < self.input.len and self.input[next_index][0] != '}') {
                    next_index += 1;
                }
                const matrix_token_ary = self.allocator.alloc([]const u8, next_index - index - 1) catch {
                    return parserError.AllocFailed;
                };
                var i = index + 1;
                for (matrix_token_ary) |*tok| {
                    tok.* = self.allocator.dupe(u8, self.input[i]) catch {
                        return parserError.AllocFailed;
                    };
                    i += 1;
                }
                newNode.*.value.?.matrix.values = matrix_token_ary;
            }
            if (root) {
                if (cur.right) |right| newNode.left = right;
                cur.right = newNode;
            } else {
                newNode.left = cur;
                cur.* = newNode.*;
            }
            Log.log.debug("parser", "matrix node parsed", null);
            return self.parse(root, cur, next_index + 1);
        } else {
            return parserError.InvalidToken;
        }
    }

    pub fn Parse(self: *parser) parserError!ast {
        var start = Ast.Node{ .left = null, .right = null, .value = null };
        return self.parse(false, &start, 0);
    }
    fn parse(self: *parser, root: bool, cur: *Ast.Node, index: usize) parserError!ast {
        if (index >= self.input.len) {
            return self.statements;
        }
        Log.log.debug("parser", self.input[index], null);
        Log.log.debug("parser", "parsing node", null);
        const cur_token = self.input[index];
        const new_index = index + 1;
        if (KEYWORD_MAP.get(cur_token)) |kw| {
            return self.parse_keyword(root, cur, new_index, kw);
        }

        if (OPERATOR_MAP.get(cur_token)) |opp| {
            Log.log.debug("parser", "operator found", null);
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
        if (try self.scan_for_matrix_init(cur_token)) {
            Log.log.debug("parser", "matrix init scanned", null);
            return self.parse_matrix(root, cur, new_index, cur_token);
        }

        return self.parse_expression(root, cur, new_index, cur_token);
    }

    fn scan_for_matrix_init(_: *parser, check: []const u8) parserError!bool {
        var check_index: usize = 0;
        while (check_index < check.len and ('0' <= check[check_index] and check[check_index] <= '9')) {
            check_index += 1;
        }
        if (0 < check_index and check_index < check.len and check[check_index] == 'x') {
            return true;
        }
        return false;
    }
};
