const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    var target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    // const version = b.version(0, 0, 1);

    // const lib = b.addSharedLibrary("beam", "src/lib.zig", version);
    // lib.setTarget(target);
    // lib.setBuildMode(mode);
    // lib.install();

    // Build executable
    const exe = b.addExecutable("zig-changed", "src/main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.linkSystemLibrary("c");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Build tests
    var tests = b.addTest("src/main.zig");
    tests.emit_bin = true;
    tests.setTarget(target);
    tests.setBuildMode(mode);

    // TODO(lbayes): Figure out how to build platform-specific test
    // Run the tests
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests.step);
}
