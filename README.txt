The original spreadsheet program VisiCalc (mostly) recreated in C from scratch!
The VisiCalc manual can be found at http://toastytech.com/manuals/VisiCalc%201.1.pdf

Zig is used for building. The build.zig file compiles the C code and links it together.

zig build       -- run will build and run the program.
zig build clean -- will remove the build artifacts.
zig build run   -- will build and run the program. This is the default if no arguments are given.
zig build test  -- will build and run the tests.
