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

    pub fn appendArgs(self: *ArgParser, args: []Arg) !void {
        for (args) |arg| {
            try self.append(arg);
        }
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
    End,
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

const LexState = enum {
    Ready,
    TakingDash,
    TakingName,
    TakingValue,
    TakingFlag,
    TakingString,
};

const LexArg = struct {
    name: []u8 = "",
    value: []u8 = "",
};

const LexError = error{
    MissingName,
    MissingValue,
    UnexpectedValue,
    UnexpectedSymbol,
};

const Lexer = struct {
    allocator: *Allocator,
    state: LexState = LexState.Ready,
    buffer: ArrayList(u8),
    result: []LexArg = undefined,

    pub fn init(a: *Allocator) !*Lexer {
        const instance = try a.create(Lexer);
        const buffer = ArrayList(u8).init(a);
        instance.* = Lexer{
            .allocator = a,
            .buffer = buffer,
        };
        return instance;
    }

    pub fn setState(self: *Lexer, state: LexState) ?LexState {
        self.state = state;

        switch (state) {
            LexState.Ready => {},
            LexState.TakingDash => {},
            LexState.TakingName => {},
            LexState.TakingValue => {},
            LexState.TakingFlag => {},
            LexState.TakingString => {},
        }

        return self.state;
    }

    fn handleToken(self: *Lexer, token: Token, arg: *LexArg) ?LexArg {
        return null;
    }

    pub fn deinit(self: *Lexer) void {
        for (self.result) |arg| {
            self.allocator.free(arg.name);
            if (arg.value.len > 0) {
                self.allocator.free(arg.value);
            }
        }
        self.allocator.destroy(self);
    }

    fn applyName(self: *Lexer, arg: *LexArg, buf: []u8) !void {
        arg.name = try self.allocator.alloc(u8, buf.len);
        mem.copy(u8, arg.name, buf);
    }

    fn applyValue(self: *Lexer, arg: *LexArg, buf: []u8) !void {
        arg.value = try self.allocator.alloc(u8, buf.len);
        mem.copy(u8, arg.value, buf);
    }

    pub fn lex(self: *Lexer, tokens: []Token, args: []LexArg) ![]LexArg {
        var buf: [256]u8 = undefined;
        var buf_index: usize = 0;
        var arg_index: usize = 0;
        var token_index: usize = 0;
        var arg: LexArg = undefined;

        while (token_index < tokens.len) {
            const token = tokens[token_index];

            switch (token.tag) {
                Tag.Dash => {
                    if (self.state == LexState.TakingValue) {
                        // We just pulled a boolean name with
                        // no value, followed by one or more spaces
                        // and have encountered a dash, close out
                        // the boolean and start fresh
                        buf_index = 0;
                        args[arg_index] = arg;
                        arg_index += 1;
                    }

                    // Starting a new arg
                    self.state = LexState.TakingName;
                },
                Tag.Char => {
                    // digest chars until space or equal
                    buf[buf_index] = token.value;
                    buf_index += 1;
                },
                Tag.BSlash => {
                    // digest chars until space or equal
                    buf[buf_index] = token.value;
                    buf_index += 1;
                },
                Tag.FSlash => {
                    // digest chars until space or equal
                    buf[buf_index] = token.value;
                    buf_index += 1;
                },
                Tag.Space => {
                    // TODO(lbayes): Handle escape sequences and inside quotations
                    // TODO(lbayes): Handle boolean flags (i.e., no value segment)
                    if (self.state == LexState.TakingName) {
                        // arg = LexArg{};
                        // try self.applyName(&arg, buf[0..buf_index]);
                        // buf_index = 0;
                        // args[arg_index] = arg;
                        // arg_index += 1;

                        arg = LexArg{};
                        try self.applyName(&arg, buf[0..buf_index]);
                        buf_index = 0;
                        self.state = LexState.TakingValue;
                    } else if (self.state == LexState.TakingValue) {
                        try self.applyValue(&arg, buf[0..buf_index]);
                        buf_index = 0;
                        args[arg_index] = arg;
                        arg_index += 1;
                        self.state = LexState.Ready;
                    } else {
                        return LexError.UnexpectedSymbol;
                    }
                },
                Tag.Equal => {
                    if (self.state == LexState.TakingName) {
                        arg = LexArg{};
                        try self.applyName(&arg, buf[0..buf_index]);
                        buf_index = 0;
                        self.state = LexState.TakingValue;
                    } else {
                        return LexError.UnexpectedSymbol;
                    }
                },
                Tag.Quote => {},
                Tag.End => {
                    if (self.state == LexState.TakingName) {
                        arg = LexArg{};
                        try self.applyName(&arg, buf[0..buf_index]);
                        buf_index = 0;
                        args[arg_index] = arg;
                        arg_index += 1;
                    } else if (self.state == LexState.TakingValue) {
                        try self.applyValue(&arg, buf[0..buf_index]);
                        buf_index = 0;
                        args[arg_index] = arg;
                        arg_index += 1;
                    }
                },
            }

            token_index += 1;
        }
        self.result = args[0..arg_index];

        return self.result;
    }
};

test "Lexer.lex with boolean arg" {
    var t_buf: [40]Token = undefined;
    var a_buf: [3]LexArg = undefined;

    const lexer = try Lexer.init(talloc);
    defer lexer.deinit();

    var tokens = try tokenize(talloc, "--abcd=efgh --ijkl --mnop", &t_buf);
    const results = try lexer.lex(tokens[0..], &a_buf);

    try expectEqual(results.len, 3);
    var result = results[0];
    try expectEqualStrings(result.name, "abcd");
    try expectEqualStrings(result.value, "efgh");

    result = results[1];
    try expectEqualStrings(result.name, "ijkl");
    try expectEqualStrings(result.value, "");

    result = results[2];
    try expectEqualStrings(result.name, "mnop");
    try expectEqualStrings(result.value, "");
}

test "Lexer.lex name value othername othervalue" {
    var t_buf: [128]Token = undefined;
    var a_buf: [2]LexArg = undefined;

    const lexer = try Lexer.init(talloc);
    defer lexer.deinit();

    var tokens = try tokenize(talloc, "--abcd efgh --ijkl mnop", &t_buf);
    const results = try lexer.lex(tokens[0..], &a_buf);

    try expectEqual(results.len, 2);
    var result = results[0];
    try expectEqualStrings(result.name, "abcd");
    try expectEqualStrings(result.value, "efgh");
}

test "Lexer.lex name=value othername=othervalue" {
    var t_buf: [128]Token = undefined;
    var a_buf: [2]LexArg = undefined;

    const lexer = try Lexer.init(talloc);
    defer lexer.deinit();

    var tokens = try tokenize(talloc, "--abcd=efgh --ijkl=mnop", &t_buf);
    const results = try lexer.lex(tokens[0..], &a_buf);

    try expectEqual(results.len, 2);
    var result = results[0];
    try expectEqualStrings(result.name, "abcd");
    try expectEqualStrings(result.value, "efgh");
}

test "Lexer.lex name value" {
    var t_buf: [128]Token = undefined;
    var a_buf: [2]LexArg = undefined;

    const lexer = try Lexer.init(talloc);
    defer lexer.deinit();

    var tokens = try tokenize(talloc, "--abcd efgh", &t_buf);
    const results = try lexer.lex(tokens[0..], &a_buf);

    try expectEqual(results.len, 1);
    var result = results[0];
    try expectEqualStrings(result.name, "abcd");
    try expectEqualStrings(result.value, "efgh");
}

test "Lexer.lex name=value" {
    var t_buf: [128]Token = undefined;
    var a_buf: [2]LexArg = undefined;

    const lexer = try Lexer.init(talloc);
    defer lexer.deinit();

    var tokens = try tokenize(talloc, "--abcd=efgh", &t_buf);
    const results = try lexer.lex(tokens[0..], &a_buf);

    try expectEqual(results.len, 1);
    var result = results[0];
    try expectEqualStrings(result.name, "abcd");
    try expectEqualStrings(result.value, "efgh");
}

test "Lexer.lex bool arg" {
    var t_buf: [128]Token = undefined;
    var a_buf: [2]LexArg = undefined;

    const lexer = try Lexer.init(talloc);
    defer lexer.deinit();

    var tokens = try tokenize(talloc, "--abcd", &t_buf);
    const results = try lexer.lex(tokens[0..], &a_buf);

    try expectEqual(results.len, 1);

    var result = results[0];
    try expectEqualStrings(result.name, "abcd");
    try expectEqualStrings(result.value, "");
}

test "Lexer.lex empty tokens" {
    var t_buf: [128]Token = undefined;
    var a_buf: [2]LexArg = undefined;

    const lexer = try Lexer.init(talloc);
    defer lexer.deinit();

    const args = try lexer.lex(t_buf[0..0], &a_buf);
    try expectEqual(args.len, 0);
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
