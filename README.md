f - A file-operation toolkit
=

Select files and operate on them.

Usage:
    f [OPTION...]

Options:

    select <file>           select a file.
    unselect <pattern>      unselect file matching pattern.
    list                    show selected files.
    <pattern> exec <cmd>    operate on files matching pattern with custom command.

Patterns:

    <pattern>  = <sequence> || <range> || 'all'
    <sequence> = <index-1> <index-2> ... <index-n>
    <range>    = <index-start>:<index-end>

Examples:

    # Just create some files to work with and select them using f.
    :/tmp$ touch one two three four
    :/tmp$ f select one two three four

    # Unselect the fourth file again.
    :/tmp$ f -u four

    # List selected files.
    :/tmp$ f -l
        1   /tmp/one
        2   /tmp/two
        3   /tmp/three

    # Copy first and second file to another directory.
    :/tmp$ f -g 1 2 -exec cp {} /some/other/path/ \;

    # Change and move file into current directory.
    :/tmp$ cd /another/path/
    :/another/path/$ f -g 3 -exec mv {} ./ \;

    # Unselect all selected files.
    :/another/path/$ f clear
