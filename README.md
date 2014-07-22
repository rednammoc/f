f - A file-operation toolkit
=

Select files and operate on them later. Add custom commands to be more flexible.

Usage:
    f [OPTION...]

Options:

    select <file>       select a file.      
    unselect <index>    unselect nth file.
    unselect all        unselect all files.
    list                show selected files.
    <cmd> <index>       operate on the nth selected file.

Examples:

    # Note: Preconfigured commands are "mv" and "cp"

    # Select some existing files
    :/tmp$ f select one two three

    # List selected files
    :/tmp$ f list
        1   /tmp/one
        2   /tmp/two
        3   /tmp/three

    # Change and copy files into another directory. 
    :/tmp$ cd /some/other/path/
    :/some/other/path/$ f cp 1 2
        1   /tmp/one
        2   /tmp/two

    # Change and move file into another directory.
    # Note: This will also unselect the file.
    :/tmp$ cd /another/path/
    :/another/path/$ f mv 3
        3   /tmp/three

