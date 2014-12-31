f - A file-operation toolkit
=

Select files and operate on them.

Usage:
    f [OPTION...]

Options:

    -s <file> || select <file>
      select a file.
    -u <pattern> || unselect <pattern>
      unselect file matching pattern.
    -l || list
      show selected files.
    <pattern> -e <command> || <pattern> exec <command>
      operate on files matching pattern with custom command.

Patterns:

    <pattern>  = <sequence> || <range> || 'all'
    <sequence> = <index-1> <index-2> ... <index-n>
    <range>    = <index-start>:<index-end>

Examples:

    # Just create some files to work with and select them using f.
    :/tmp$ touch one two three four
    :/tmp$ f select one two three four

    # Unselect the fourth file again.
    :/tmp$ f unselect four

    # List selected files.
    :/tmp$ f list
        1   /tmp/one
        2   /tmp/two
        3   /tmp/three

    # Copy first and second file to another directory.
    #  You can use the index or filename for selection.
    :/tmp$ f 1 two -exec cp {} /some/other/path/ \;

    # Move a file into your current directory.
    :/tmp$ cd /another/path/
    :/another/path/$ f three -exec mv {} ./ \;

    # Unselect all selected files.
    :/another/path/$ f clear
    :/another/path/$ f unselect all
