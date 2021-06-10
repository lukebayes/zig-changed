const std = @import("std");

const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;
const ArrayList = std.ArrayList;
const CompTimeStringMap = std.CompTimeStringMap;
const Writer = std.io.Writer;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const fmt = std.fmt;
const io = std.io;
const mem = std.mem;
const print = std.debug.print;
const process = std.process;
const talloc = std.testing.allocator;

const ArgsList = ArrayList(Arg);

pub const ArgumentError = error{
    MissingExe,
    MissingFiles,
    InvalidFile,
    InvalidFiles,
};

pub const ArgType = enum {
    File,
    Flag,
    Integer,
    Float,
    String,
};

pub const Arg = struct {
    name: []const u8,
    arg_type: ArgType,
    short: []const u8 = "",
    desc: []const u8,
    is_req: bool,
};

pub const ArgParser = struct {
    allocator: *Allocator,
    args: ArgsList,
    exe_name: []const u8 = "",
    exe_desc: []const u8 = "",

    pub fn init(a: *Allocator) !*ArgParser {
        print("\nArgParser.init() called\n", .{});
        var parser = try a.create(ArgParser);
        var args = ArgsList.init(a);

        parser.* = ArgParser{
            .allocator = a,
            .args = args,
        };

        return parser;
    }

    pub fn append(self: *ArgParser, arg: Arg) !void {
        try self.args.append(arg);
    }

    pub fn deinit(self: *ArgParser) void {
        self.args.deinit();
        self.allocator.destroy(self);
    }

    pub fn usage(self: *ArgParser, buffer: anytype) !void {
        try fmt.format(buffer,
            \\{s} {s}
            \\Usage: {s}
            \\  Options:
        , .{ self.exe_name, self.exe_desc, self.exe_name });
    }

    // NOTE(lbayes): std.os.args are: [][*:0]u8, we need to provide
    // an easy way to convert this to a slice of []const u8.
    pub fn parse(self: *ArgParser, input: [][]const u8) !void {
        print("YOOO: {s}\n", .{input});
        for (input) |arg, index| {
            if (index > 0) {
                print("arg: {s}\n", .{arg});
            }
        }
        // for (input) |arg| {
        // }
        // var segment = input.next(self.allocator);
        // while (segment != null) : (segment = input.next()) {
        // print("Seg: {s}\n", .{segment});
        // }
    }
};

const Tag = enum {
    BSlash,
    Char,
    Dash,
    Equal,
    FSlash,
    Quote,
    Space,
};

const Token = struct {
    tag: Tag = undefined,
    start: usize,
    end: usize,
    value: u8 = '0',
};

fn tokenize(a: *Allocator, arg: []const u8, tokens: []Token) ![]Token {
    if (arg.len == 0) {
        return tokens[0..0];
    }

    var token_index: u32 = 0;
    var char_index: usize = 0;
    var char = arg[0];

    while (char_index < arg.len) {
        var token = Token{
            .start = char_index,
            .end = char_index + 1,
            .value = char,
        };

        char = arg[char_index];

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

    return tokens[0..token_index];
}

const LexState = enum {
    Ready,
    TakingName,
    TakingValue,
    TakingFlag,
    TakingString,
};

const LexArg = struct {
    name: []u8 = "",
    value: []u8 = "",
};

const LexCmd = enum {
    StartArg,
    StartValue,
    End,
    Ignore,
};

const Lexer = struct {
    allocator: *Allocator,
    state: LexState = LexState.Ready,
    buffer: ArrayList(u8),

    pub fn init(a: *Allocator) !*Lexer {
        const instance = try a.create(Lexer);
        const buffer = ArrayList(u8).init(a);
        instance.* = Lexer{
            .allocator = a,
            .buffer = buffer,
        };
        return instance;
    }

    pub fn setState(self: *Lexer, state: LexState) !LexCmd {
        const cmd = try self.updateState(state);
        print("CMD: {s}\n", .{cmd});
        return cmd;
    }

    fn updateState(self: *Lexer, state: LexState) LexCmd {
        if (self.state == state) {
            return;
        }
        const last_state = self.state;
        if (last_state != state) {
            self.state = state;

            if (last_state == LexState.TakingName or
                last_state == LexState.StartArg or
                last_state == LexState.StartValue)
            {
                return LexCmd.End;
            }

            switch (state) {
                LexState.Ready => {},
                LexState.TakingName => {
                    return LexCmd.StartArg;
                },
                LexState.TakingValue => {
                    return LexCmd.StartArg;
                },
                LexState.TakingFlag => {
                    return LexCmd.StartArg;
                },
                LexState.TakingString => {
                    return LexCmd.StartValue;
                },
                else => {},
            }
        }
    }

    pub fn deinit(self: *Lexer) void {
        self.allocator.destroy(self);
    }

    pub fn parse(self: *Lexer, tokens: []Token, args: []LexArg) ![]LexArg {
        if (tokens.len == 0) {
            return error.Fail;
        }
        if (self.state != LexState.Ready) {
            return error.Fail;
        }
        var token_index: usize = 0;
        var arg_index: usize = 0;
        while (token_index < tokens.len) {
            const token = tokens[token_index];
            var should_skip = false;
            print(">>>>>> TOKEN: {s}\n", .{token});

            token_index += 1;
        }

        return args[0..arg_index];
    }
};

test "Lexer is instantiable" {
    const lexer = try Lexer.init(talloc);
    defer lexer.deinit();
}

test "lex works" {
    var t_buff: [20]Token = undefined;
    const tokens = try tokenize(talloc, "--abcd", &t_buff);

    var a_buff: [20]LexArg = undefined;
    const lexer = try Lexer.init(talloc);
    defer lexer.deinit();

    const args = try lexer.parse(tokens, &a_buff);

    print(">>>>>>>>> ARGS RETURNED: {d}\n", .{args.len});
    // try expectEqual(args.len, 3);
}

// fn lex(a: *Allocator, tokens: []Token, args: []LexArg) ![]LexArg {
//     if (tokens.len == 0) {
//         return error.Fail;
//     }
//
//     var state = LexState.Ready;
//     var token_index: usize = 0;
//     var arg_index: usize = 0;
//     var arg: LexArg = undefined;
//     var nameList = ArrayList(u8).init(a);
//     var valueList = ArrayList(u8).init(a);
//
//     while (token_index < tokens.len) {
//         const token = tokens[token_index];
//         var should_skip = false;
//
//         switch (token.tag) {
//             Tag.Dash => {
//                 state = LexState.TakingName;
//                 arg = LexArg{};
//                 should_skip = true;
//             },
//             Tag.Space => {
//                 if (state != LexState.TakingString) {
//                     if (state == LexState.TakingFlag) {
//                         state = LexState.Ready;
//                     } else if (state == LexState.TakingName) {
//                         state = LexState.TakingValue;
//                     }
//
//                     should_skip = true;
//                 }
//             },
//             Tag.Equal => {
//                 if (state == LexState.TakingName) {
//                     state = LexState.TakingValue;
//                     should_skip = true;
//                 }
//             },
//             else => {},
//         }
//
//         if (!should_skip) {
//             if (state == LexState.TakingName or state == LexState.TakingFlag) {
//                 try nameList.append(token.value);
//             } else if (state == LexState.TakingValue) {
//                 try valueList.append(token.value);
//             }
//         }
//
//         token_index += 1;
//     }
//
//     return args[0..arg_index];
// }

test "tokenize works" {
    var buffer: [20]Token = undefined;
    const tokens = try tokenize(talloc, "--abcd", &buffer);

    // for (tokens |token, index| {
    // print(">>> FOUND: {s} {c}\n", .{ token, token.value });
    // }

    try expectEqual(tokens.len, 6);
    try expectEqual(tokens[0].tag, Tag.Dash);
    try expectEqual(tokens[1].tag, Tag.Dash);
    try expectEqual(tokens[2].tag, Tag.Char);
    try expectEqual(tokens[3].tag, Tag.Char);
    try expectEqual(tokens[4].tag, Tag.Char);
    try expectEqual(tokens[5].tag, Tag.Char);
}

test "ArgParser is instantiable" {
    var p = try ArgParser.init(talloc);
    p.exe_name = "abcd";
    p.exe_desc = "Runs the abc's";

    defer p.deinit();
    try expectEqualStrings(p.exe_name, "abcd");
    try expectEqualStrings(p.exe_desc, "Runs the abc's");
}

test "ArgParser append" {
    var p = try ArgParser.init(talloc);
    p.exe_name = "abcd";
    p.exe_desc = "makes everything just a little more difficult";

    defer p.deinit();

    try p.append(.{
        .arg_type = ArgType.String,
        .name = "foo",
        .short = "f",
        .desc = "Foo the foo",
        .is_req = true,
    });

    try p.append(.{
        .arg_type = ArgType.String,
        .name = "bar",
        .short = "b",
        .desc = "Bar the bar",
        .is_req = false,
    });

    var buf: [512]u8 = undefined;
    var buf_stream = io.fixedBufferStream(&buf);
    var writer = buf_stream.writer();
    try p.usage(writer);
    var lines = mem.split(buf_stream.getWritten(), "\n");

    var line = try lines.next() orelse error.Fail;
    try expectEqualStrings(line, "abcd makes everything just a little more difficult");

    line = try lines.next() orelse error.Fail;
    try expectEqualStrings(line, "Usage: abcd");

    line = try lines.next() orelse error.Fail;
    try expectEqualStrings(line, "  Options:");

    var empty = lines.next();
    try expect(empty == null);
}

test "ArgParser.parse" {
    var p = try ArgParser.init(talloc);
    p.exe_name = "abcd";
    p.exe_desc = "makes everything just a little more difficult";

    defer p.deinit();

    try p.append(.{
        .name = "name",
        .short = "n",
        .desc = "Name for the parameter",
        .is_req = true,
        .arg_type = ArgType.String,
    });

    try p.append(.{
        .name = "flag",
        .short = "f",
        .desc = "Do it if present",
        .is_req = false,
        .arg_type = ArgType.Flag,
    });

    try p.append(.{
        .name = "color",
        .short = "c",
        .desc = "Set the color",
        .is_req = false,
        .arg_type = ArgType.String,
    });

    try p.append(.{
        .name = "unused",
        .short = "u",
        .desc = "Unused param",
        .is_req = false,
        .arg_type = ArgType.String,
    });

    var argv = [_][]const u8{
        "cmd",
        "--name=efgh",
        "--bigflag",
        "--color",
        "green",
    };

    var itr = try p.parse(argv[0..]);
}
