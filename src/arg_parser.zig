const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const expectEqualStrings = std.testing.expectEqualStrings;
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
    arg_type: ArgType = ArgType.File,
    short: []const u8 = "",
    desc: []const u8 = "",
};

pub const ArgParser = struct {
    allocator: *Allocator,
    args: ArgsList,

    pub fn init(a: *Allocator, exe_name: []const u8, desc: []const u8) !*ArgParser {
        print("\nArgParser.init() called\n", .{});
        var parser = try a.create(ArgParser);
        var args = ArgsList.init(a);
        var exe_arg = Arg{
            .arg_type = ArgType.String,
            .name = exe_name,
            .desc = desc,
            .short = "",
        };

        try args.append(exe_arg);

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

    pub fn getExe(self: *ArgParser) []const u8 {
        return self.args.items[0].name;
    }

    pub fn getDesc(self: *ArgParser) []const u8 {
        return self.args.items[0].desc;
    }

    pub fn usage(self: *ArgParser) void {
        const exe_name = self.getExe();
        print(
            \\{s} {s}
            \\Usage: {s}
            \\  Options:
        , .{ exe_name, self.getDesc(), exe_name });
    }
};

test "ArgParser is instantiable" {
    var p = try ArgParser.init(talloc, "abcd", "Runs the abc's");
    defer p.deinit();
    try expectEqualStrings(p.getExe(), "abcd");
}

test "ArgParser append" {
    var p = try ArgParser.init(talloc, "fake-app", "fake-app-desc");
    defer p.deinit();
    try expectEqualStrings(p.getExe(), "fake-app");

    try p.append(.{
        .arg_type = ArgType.String,
        .name = "foo",
        .short = "f",
        .desc = "Foo the foo to the bar",
    });

    try p.append(.{
        .arg_type = ArgType.String,
        .name = "bar",
        .short = "b",
        .desc = "Bar the bar to the foo",
    });

    p.usage();
}
