#!/bin/bash
# @name: f.sh
# @version: 0.54
# @description: file-operation toolkit. 
# @author: rednammoc
# @date: 26/07/22

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

    # Check that index is 1 <= x <= size(list)
    is_index_within_list () {
        local index="${1}" ; local line_count=$(wc -l < "${_F_LIST}") ; 
        is_numeric "${index}" && [ "${index}" -le ${line_count} ] 
    }

    is_numeric () {
        [[ "${1}" =~ ^[1-9][0-9]*$ ]]
    }

    # Return list-entry at specified position
    get_entry () {
        local index="$1" ; 
        if ! is_index_within_list "${index}" ; then
            echo "Illegal argument." >&2 && return 1
        fi
        sed -n ${index}p < "${_F_LIST}"
    }

    # Select files from list. 
    #
    # Arguments:
    #  <pattern>  = <sequence> || <range> || 'all'
    #  <sequence> = <index-1> <index-2> ... <index-n>
    #  <range>    = <index-start>:<index-end>
    #
    get_files_from_list () {
        if [ "${#@}" -ne 0 ] ; then
            for ARG in "$@" ; do
                if is_numeric "${ARG}" ; then       # <sequence>
                    if ! is_index_within_list "${ARG}" ; then
                        echo "Illegal argument. Index out of range." >&2 && return 1
                    fi
                    print_entry_by_index "${ARG}" || return 1
                elif [[ "${ARG}" == 'all' ]] ; then # 'all'
                    local line_count=$(wc -l < "${_F_LIST}") ; 
                    get_files_from_list $(seq 1 "${line_count}")
                    return $?
                elif [[ "${ARG}" == *:* ]] ; then   # <range>
                    IFS=':' read -ra RANGE <<< "${ARG}"
                    if [ "${#RANGE[@]}" -ne "2" ] ; then
                        echo "Illegal argument. Range has wrong format." >&2 && return 1
                    elif  ! is_index_within_list "${RANGE[0]}" || 
                        ! is_index_within_list "${RANGE[1]}" ; then
                        echo "Illegal argument. Range out of bounds." >&2 && return 1
                    fi
                    get_files_from_list $(seq "${RANGE[0]}" "${RANGE[1]}") || return 1
                else
                    echo "Illegal argument." >&2 && return 1
                fi
            done
        fi
    }

    print_selected_files_from_list () {
        get_files_from_list $@ | sort -n | uniq
    }

    print_entry_by_index () {
        local index="$1" ; local file=$(get_entry "${index}")
        [ -n "${file}" ] && print_entry "${index}" "${file}"
    }

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
    elif ( [ "$1" == "clear" ] || [ "$1" == "-c" ] ) ; then
        > "${_F_LIST}"
    elif ( [ "$1" == "select" ] || [ "$1" == "-s" ] ) ; then
        local file="${2}" ; local index=0
        if   [ -z "${file}" ] ; then echo "Illegal argument." >&2; return 1; fi
        if ! [ -f "${file}" ] ; then echo "File does not exist." >&2; return 1; fi
        # Resolve relative path
        if ! [[ "${file}" = /* ]] ; then file="`pwd`/${file}" ; fi
        # Check for duplicate entries
        if [ -f "${_F_LIST}" ] ; then
            if grep -Fxq "${file}" "${_F_LIST}" ; then
                index=`grep -Fxnm 1 "${file}" "${_F_LIST}" | grep -oEi '^[0-9]+'`
                echo "The file '${file}' is already selected (#${index})." >&2 && return 1
            fi
        fi
        echo "${file}" >> "${_F_LIST}"	
        index=$(wc -l < "${_F_LIST}") 
        print_entry "${index}" "${file}"
    elif ( [ "$1" == "unselect" ] || [ "$1" == "-u" ] ) ; then
        shift 1; local selected_files=$(print_selected_files_from_list $@)
        while read -r index file ; do
            sed -e "${index}d" "${_F_LIST}" > "${_F_LIST}.tmp" && 
                mv "${_F_LIST}.tmp"  "${_F_LIST}" &&
                print_entry "${index}" "${file}"
        done <<< "${selected_files}"
    elif ( [ "$1" == "get" ] || [ "$1" == "-g" ] ) ; then
        shift 1 ; print_selected_files_from_list $@
    else
        local cmd="$1"; shift 1;
        local does_cmd_exist=$(ls -1 "${_F_CMD_DIR}" | grep "^${cmd}$")
        if ( [ -z "${cmd}" ] || [ -z "${does_cmd_exist}" ] ) ; then
            echo "Usage: f [-adl] [args]" && return 1
        fi
        ${_F_CMD_DIR}/${cmd} $@
    fi
}
f $@
