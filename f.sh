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
    local _F_CMD_DIR="${_F_CONFIG_DIR}/cmd"
    ! [ -d "${_F_CMD_DIR}" ] && mkdir -p "${_F_CMD_DIR}"
    ! [ -f "${_F_CONFIG}" ] && 
        echo "_F_LIST=\"${_F_CONFIG_DIR}/f.list\"" >> "${_F_CONFIG}"
    source "${_F_CONFIG}"

    # Assert that index is numeric and within list
    validate_index () {
        local index="${1}"
        validate_index_numeric "${index}" && validate_index_within_list "${index}" ;
    }

    # Assert that index is numeric
    validate_index_numeric () {
        local index="${1}" ; 
        [[ "${index}" =~ ^[1-9][0-9]*$ ]]
    }

    # Assert that index is 1 <= x <= size(list)
    validate_index_within_list () {
        local index="${1}" ; local line_count=$(wc -l < "${_F_LIST}") ; 
        ! [ "${index}" -gt ${line_count} ] 
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
        if [ "${#@}" -ne 0 ] ; then
            for ARG in "$@" ; do
                if validate_index_numeric "${ARG}" ; then
                    # get entry by index when argument is numeric
                    if ! validate_index_within_list "${ARG}" ; then
                        echo "Illegal argument. Index out of range." >&2
                        return 1
                    fi
                    echo $(get_entry "${ARG}")
                elif [[ "${ARG}" == 'all' ]] ; then
                    # get all entries when argument matches wildcard
                    local line_count=$(wc -l < "${_F_LIST}") ; 
                    print_file_list $(seq 1 "${line_count}")
                    return $?
                elif [[ "${ARG}" == *:* ]] ; then
                    # get entries inbetween range when argument matches <start-index>:<end-index>
                    IFS=':' read -ra RANGE <<< "${ARG}"
                    if [ "${#RANGE}" -ne "2" ] || 
                        ! validate_index "${RANGE}[0]" || 
                        ! validate_index "${RANGE}[1]" ; then
                        echo "Illegal argument." >&2
                        return 1
                    fi                 
                    print_file_list $(seq "${RANGE}[0]" "${RANGE}[1]")
                else
                    echo "Illegal argument." >&2
                    return 1
                fi
                [ $? -eq 1 ] && return 1
            done
        fi
    }

    # Generate file list from command-line-arguments
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
            cat -n "${_F_LIST}"
        fi
    elif ( [ "$1 $2" == "unselect all" ] || [ "$1" == "clear" ] || 
            [ "$1" == "-ua" ] || [ "$1" == "-c" ] ) ; then
        > "${_F_LIST}"
    elif ( [ "$1" == "select" ] || [ "$1" == "-s" ] ) ; then
        local file="${2}" ; local index=0
        if   [ -z "${file}" ] ; then echo "Illegal argument." >&2; return 1; fi
        if ! [ -f "${file}" ] ; then echo "File does not exist." >&2; return 1; fi
        # Relative or absolute path?
        if ! [[ "${file}" = /* ]] ; then file="`pwd`/${file}" ; fi
        # Check for duplicate entries
        if [ -f "${_F_LIST}" ] ; then
            if grep -Fxq "${file}" "${_F_LIST}" ; then
                index=`grep -Fxnm 1 "${file}" "${_F_LIST}" | grep -oEi '^[0-9]+'`
                echo "The file '${file}' is already selected (#${index})." >&2
                return 1
            fi
        fi
        echo "${file}" >> "${_F_LIST}"	
        index=$(wc -l < "${_F_LIST}") 
        print_entry "${index}" "${file}"
    elif ( [ "$1" == "unselect" ] || [ "$1" == "-u" ] ) ; then
        local index="$2" ; local file=$(get_entry "${index}")
        [ -z "${file}" ] && return 1
        print_entry "${index}" "${file}"
        sed -e "${index}d" "${_F_LIST}" > "${_F_LIST}.tmp" && 
            mv "${_F_LIST}.tmp"  "${_F_LIST}"
    else
        local cmd="$1"; shift 1;
        local does_cmd_exist=$(ls -1 "${_F_CMD_DIR}" | grep "^${cmd}$")
        if ( [ -z "${cmd}" ] || [ -z "${does_cmd_exist}" ] ) ; then
            echo "Usage: f [-adl] [args]"
            return 1
        fi
        local file_list=$(generate_file_list $@)
        ${_F_CMD_DIR}/${cmd} ${file_list}
    fi
}
f $@
