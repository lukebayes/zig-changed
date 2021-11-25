const std = @import("std");
const arg_parser = @import("arg_parser.zig");

const ArgParser = arg_parser.ArgParser;
const ArgType = arg_parser.ArgType;
const heap = std.heap;
const print = std.debug.print;
const process = std.process;
const os = std.os;
const talloc = std.testing.allocator;

pub fn main() !u8 {
    print("--------------------------------------------------\n", .{});
    print("Main Console loaded\n", .{});
    // Create the configured allocator
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) {
            @panic("MEMORY LEAK DETECTED");
        }
    }

    // Create an arg parser
    const parser = try ArgParser.init(&gpa.allocator);
    defer parser.deinit();

    try parser.append(.{
        .name = "abcd",
        .short = "a",
        .desc = "Foo the foo",
        .is_req = true,
        .arg_type = ArgType.String,
    });
    try parser.append(.{
        .name = "efgh",
        .short = "e",
        .desc = "Bar the bar",
        .is_req = false,
        .arg_type = ArgType.String,
    });

    // const itr = try parser.parse(os.argv);

    return 0;
}

test "ArgParser is instantiable" {
    var p = try ArgParser.init(talloc);
    defer p.deinit();
}
