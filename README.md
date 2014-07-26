f - A file-operation toolkit
=

Select files and operate on them later. Add custom commands to be more flexible.

Usage:
    f [OPTION...]

Options:

    select <file>       select a file.      
    unselect <pattern>  unselect file matching pattern.
    list                show selected files.
    get <pattern>       get file matching pattern.
    <cmd> <pattern>     operate on files matching pattern with custom command.

Patterns:

    <pattern>  = <sequence> || <range> || 'all'
    <sequence> = <index-1> <index-2> ... <index-n>
    <range>    = <index-start>:<index-end>           

Custom Commands:

You can trigger custom commands, by placing them into ~/.config/f/cmd/.

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

