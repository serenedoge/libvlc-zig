const std = @import("std");
const vlc = @import("vlc");
const vlc_version = vlc.Version;
const zig_version = @import("builtin").zig_version;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout = std.Io.File.stdout().writer(io, &.{});

    stdout.interface.print("LibVLC version: {s}.\n", .{vlc.get_version()}) catch @panic("Cannot print libvlc version");
    stdout.interface.print("LibVLC compiler: {s}.\n", .{vlc.get_compiler()}) catch @panic("Cannot print libvlc compiler");
    stdout.interface.print("LibVLC changeset: {s}.\n", .{vlc.get_changeset()}) catch @panic("Cannot print libvlc changeset");

    if (vlc_version.major >= 4)
        stdout.interface.print("LibVLC ABI version: {d}.\n", .{vlc.get_abiVersion()}) catch @panic("Cannot print libvlc ABI");

    stdout.interface.print("Zig version: {}.\n", .{zig_version}) catch @panic("Cannot print zig version");
}
