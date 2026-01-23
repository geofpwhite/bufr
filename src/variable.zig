const std = @import("std");
const Type = @import("types.zig").Type;
const Matrix = @import("types.zig").Matrix;
const MatrixType = @import("types.zig").MatrixType;
const Ast = @import("ast.zig");

pub const evalValue = union(enum) {
    integer: i64,
    float: f64,
    boolean: bool,
    matrix: Matrix,
};

const VarError = error{
    InvalidType,
};

pub const variable = struct {
    type: Type,
    name: []const u8,
    data: evalValue,

    pub fn init(allocator: std.mem.Allocator, varType: Type, name: []const u8, data: Ast.astValue) !variable {
        return variable{
            .type = varType,
            .name = name,
            .data = switch (data) {
                .integer => |value| .{ .integer = value },
                .float => |value| .{ .float = value },
                .boolean => |value| .{ .boolean = value },
                .matrix => |value| .{
                    .matrix = try Matrix.new(
                        allocator,
                        value.rows,
                        value.cols,
                        if (value.elementType) |typ| typ else MatrixType.Float,
                    ),
                },
                else => return VarError.InvalidType,
            },
        };
    }
};
