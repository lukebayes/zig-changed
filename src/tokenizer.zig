const std = @import("std");

const Allocator = std.mem.Allocator;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const print = std.debug.print;
const talloc = std.testing.allocator;

pub const Tag = enum {
    BSlash,
    Char,
    Dash,
    Equal,
    FSlash,
    Quote,
    Space,
    End,
};

pub const Token = struct {
    tag: Tag = undefined,
    start: usize,
    end: usize,
    value: u8 = '0',
};

pub fn tokenize(a: *Allocator, arg: []const u8, tokens: []Token) ![]Token {
    if (arg.len == 0) {
        return tokens[0..0];
    }

    var token_index: u32 = 0;
    var char_index: usize = 0;

    while (char_index < arg.len) {
        var char = arg[char_index];

        var token = Token{
            .start = char_index,
            .end = char_index + 1,
            .value = arg[char_index],
        };

        switch (char) {
            '-' => {
                token.tag = Tag.Dash;
            },
            ' ' => {
                token.tag = Tag.Space;
            },
            '=' => {
                token.tag = Tag.Equal;
            },
            '"' => {
                token.tag = Tag.Quote;
            },
            else => {
                token.tag = Tag.Char;
            },
        }

        tokens[token_index] = token;
        token_index += 1;
        char_index += 1;
    }

    // End EOF token to the end of result.
    var eof_token = Token{
        .tag = Tag.End,
        .start = char_index,
        .end = char_index,
        .value = '\n',
    };

    tokens[token_index] = eof_token;
    token_index += 1;

    return tokens[0..token_index];
}

test "tokenize works" {
    var buffer: [20]Token = undefined;
    const tokens = try tokenize(talloc, "--abcd", &buffer);

    try expectEqual(tokens.len, 7);
    try expectEqual(tokens[0].tag, Tag.Dash);
    try expectEqual(tokens[0].value, '-');
    try expectEqual(tokens[1].tag, Tag.Dash);
    try expectEqual(tokens[1].value, '-');
    try expectEqual(tokens[2].tag, Tag.Char);
    try expectEqual(tokens[2].value, 'a');
    try expectEqual(tokens[3].tag, Tag.Char);
    try expectEqual(tokens[3].value, 'b');
    try expectEqual(tokens[4].tag, Tag.Char);
    try expectEqual(tokens[4].value, 'c');
    try expectEqual(tokens[5].tag, Tag.Char);
    try expectEqual(tokens[5].value, 'd');
    try expectEqual(tokens[6].tag, Tag.End);
    try expectEqual(tokens[6].value, '\n');
}

test "ArgParser is instantiable" {
    var p = try ArgParser.init(talloc);
    defer p.deinit();

    p.exe_name = "abcd";
    p.exe_desc = "Runs the abc's";

    try expectEqualStrings(p.exe_name, "abcd");
    try expectEqualStrings(p.exe_desc, "Runs the abc's");
}
