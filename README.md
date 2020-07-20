# uncovered

This tool examines coverage listing files
to identify the ones with the most uncovered lines.

## Usage

Use [dub] to build the tool:

    > dub build --build=release

Use the tool to summarize the coverage for several listing files.

For example:

    >./uncovered *.lst
    46/61 src-main.lst
    -----
    46/61 lines uncovered

Note that the results are sorted by absolute number of uncovered lines.
The shown path should allow to open the listing file with `Ctrl+Click`.

Try option `--depth=N` for a package summary limited to the given depth.

[dub]: http://code.dlang.org/
