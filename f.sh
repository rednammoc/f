#!/bin/bash
# @name: f.sh
# @version: 0.51
# @description: file-operation toolkit. 
# @author: rednammoc
# @date: 14/07/22

# INSTALL: mv to /usr/bin/f or add f-location into PATH.

# Default configuration-file
_F_CONFIG="${HOME}/.config/f/f.conf"

f () {
    # Initialize directories
    local _F_CONFIG_DIR=$(dirname "${_F_CONFIG}")
    ! [ -d "${_F_CONFIG_DIR}" ] && mkdir -p "${_F_CONFIG_DIR}"
    local _F_TAGS_DIR="${_F_CONFIG_DIR}/tags"
    ! [ -d "${_F_TAGS_DIR}" ] && mkdir -p "${_F_TAGS_DIR}"
    ! [ -f "${_F_CONFIG}" ] && 
        echo "_F_LIST=\"${_F_CONFIG_DIR}/f.list\"" >> "${_F_CONFIG}"

    # Assert that index is numeric and within list
    validate_index () {
        return validate_index_numeric "${index}" && validate_index_within_list "${index}" ;
    }

    # Assert that index is numeric
    validate_index_numeric () {
        local index="${1}" ; 
        [[ "${index}" =~ ^[1-9][0-9]*$ ]]
    }

    # Assert that index is 1 <= x <= size(list)
    validate_index_within_list () {
        local index="${1}" ; local line_count=$(wc -l < "${_F_LIST}") ; 
        return ! [ "${index}" -gt ${line_count} ] 
    }

    # Return list-entry at specified position
    get_entry () {
        local index="$1" ; 
        if ! validate_index "${index}" ; then
            echo "Illegal argument." >&2
            return 1
        fi
        sed -n ${index}p < "${_F_LIST}"
    }

    # Generate file-list from arguments
    print_file_list () {
        if ! [ -n "$@" ] ; then
            for ARG in "$@" ; do
                if validate_index_numeric "${ARG}" ; then
                    # get entry by index when argument is numeric
                    if ! validate_index "${ARG}" ; then
                        echo "Illegal argument." >&2
                        return 1
                    fi
                    echo $(get_entry "${ARG}")
                elif [[ "${ARG}" == *:* ]] ; then
                    # get entries inbetween range when argument matches <start-index>:<end-index>
                    IFS=':' read -ra RANGE <<< "${ARG}"
                    if [ "${#RANGE}" -ne "2" ] || ! validate_index "${RANGE}[0]" || ! validate_index "${RANGE}[1]" ; then
                        echo "Illegal argument." >&2
                        return 1
                    fi                 
                    print_file_list $(seq "${RANGE}[0]" "${RANGE}[1]")
                elif [[ "${ARG}" == "*" ]] ; then
                    # get all entries when argument matches wildcard
                    local line_count=$(wc -l < "${_F_LIST}") ; 
                    print_file_list $(seq 1 "${line_count}")
                    return $?
                else
                    echo "Illegal argument." >&2
                    return 1
                fi
                [ $? -eq 1 ] && return 1
            done
        fi
    }

    generate_file_list () {
        print_file_list $@ | sort -n | uniq
    }

    # Print formatted list-entry
    print_entry () {
        local index="$1"; local path="$2"
        printf "%+6s  ${path}\n" "${index}"
    }

    # Parse/Execute commandline-arguments
    if [ "$1" == "list" ] || [ "$1" == "-l" ] ; then
        local records=0; local line_count=$(wc -l < "${_F_LIST}")
        if [ -f "${_F_LIST}" ] && [[ "${line_count}" -gt 0 ]] ; then
            print_entry "Index" "Folder" 
            cat -n "${_F_LIST}"
            records=$(wc -l < "${_F_LIST}")
        fi
        echo "(Profile: $(basename "${_F_LIST}"), Records: ${records})"
    elif ( [ "$1" == "clear" ] || [ "$1" == "-c" ] ) ; then
        > "${_F_LIST}"
    elif ( [ "$1" == "add" ] || [ "$1" == "-a" ] ) ; then
        local file="${2}" ; local index=0
        if   [ -z "${file}" ] ; then echo "Illegal argument." >&2; return 1; fi
        if ! [ -f "${file}" ] ; then echo "File does not exist." >&2; return 1; fi
        # Relative or absolute path?
        if ! [[ "${file}" = /* ]] ; then file="`pwd`/${file}" ; fi
        # Check for duplicate entries
        if [ -f "${_F_LIST}" ] ; then
            if grep -Fxq "${file}" "${_F_LIST}" ; then
                index=`grep -Fxnm 1 "${file}" "${_F_LIST}" | grep -oEi '^[0-9]+'`
                echo "The file '${file}' is already in your list (#${index})." >&2
                return 1
            fi
        fi
        echo "${file}" >> "${_F_LIST}"	
        index=$(wc -l < "${_F_LIST}") 
        print_entry "${index}" "${file}"
    elif ( [ "$1" == "delete" ] || [ "$1" == "-d" ] ) ; then
        local index="$2" ; local file=$(get_entry "${index}")
        [ -z "${file}" ] && return 1
        print_entry "${index}" "${file}"
        sed -e "${index}d" "${_F_LIST}" > "${_F_LIST}.tmp" && 
            mv "${_F_LIST}.tmp"  "${_F_LIST}"
    else
        local tag="$1"; shift 2;  
        local does_tag_exist=$(ls -1 "${_F_TAGS_DIR}" | grep "^${tag}$")
        if ( [ -z "${tag}" ] || [ -z "${does_tag_exist}" ] ) ; then
            echo "Usage: f [-adl] [args]"
            return 1
        fi
        local file_list=$(generate_file_list $@)
        ${_F_TAGS_DIR}/${tag} ${file_list}
    fi
}
f $@
