const std = @import("std");
const tokenizer = @import("tokenizer.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Tag = tokenizer.tag;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const mem = std.mem;
const print = std.debug.print;
const talloc = std.testing.allocator;
const tokenize = tokenizer.tokenize;

const LexState = enum {
    Ready,
    TakingDash,
    TakingName,
    TakingValue,
    TakingFlag,
    TakingString,
};

pub const LexArg = struct {
    name: []u8 = "",
    value: []u8 = "",
};

pub const LexError = error{
    MissingName,
    MissingValue,
    UnexpectedValue,
    UnexpectedSymbol,
};

pub const Lexer = struct {
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

            // Believe me, I get it. There's some hoorific duplication
            // in here. I'm just trying to get it to work at this point,
            // so I can focus on other things. If it bugs you, please
            // feel free to clean it up!
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
