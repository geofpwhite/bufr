const std = @import("std");
const Type = @import("types.zig").Type;
const Ast = @import("ast.zig");
pub const variable = struct {
    type: Type,
    name: []const u8,
    data: Ast.astValue,

    pub fn init(varType: Type, name: []const u8, data: Ast.astValue) variable {
        return variable{
            .type = varType,
            .name = name,
            .data = data,
        };
    }
};
