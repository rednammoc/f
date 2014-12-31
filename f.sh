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
  # Initialize directories.
  local _F_CONFIG_DIR=$(dirname "${_F_CONFIG}")
  ! [ -d "${_F_CONFIG_DIR}" ] && mkdir -p "${_F_CONFIG_DIR}"
  local _F_CMD_DIR="${_F_CONFIG_DIR}/cmd"
  ! [ -d "${_F_CMD_DIR}" ] && mkdir -p "${_F_CMD_DIR}"
  ! [ -f "${_F_CONFIG}" ] &&
  echo "_F_LIST=\"${_F_CONFIG_DIR}/f.list\"" >> "${_F_CONFIG}"
  source "${_F_CONFIG}"

  # Initialize variables.
  local _CMD=""		          # cmd executed by the user. when empty no cmd is executed.
  local _TARGET="${PWD}/"	  # target used as second parameter in cmd-string. default = current directory.
  local _SELECTED_FILES=""	# contains selected files by the get-command.

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
      echo "Illegal argument. Index is not within list-range." >&2 && return 1
    fi
    sed -n ${index}p < "${_F_LIST}"
  }

  # Select files from list.
  #
  # Arguments:
  #  <pattern>  = <sequence> || <range> || 'all'
  #  <index>    = [1-9][0-9]
  #  <sequence> = <index>,<index>, ... <index>
  #  <range>    = <index-start>:<index-end>
  #
  get_files_from_list () {
    if [ "${#}" -eq 1 ] ; then
      local ARG="${1}"
      if is_numeric "${ARG}" ; then # <index>
        local index="${ARG}"
        if ! is_index_within_list "${index}" ; then
          echo "Illegal argument. Index out of range." >&2 && return 1
        fi
        print_entry_by_index "${index}" || return 1
      elif [[ "${ARG}" == *,* ]] ; then # <sequence>
        IFS=',' read -ra SEQUENCE <<< "$ARG"
        for index in "${SEQUENCE[@]}"; do
          if is_numeric "${index}" ; then
            if ! is_index_within_list "${index}" ; then
              echo "Illegal argument. Index out of range." >&2 && return 1
            fi
            print_entry_by_index "${index}" || return 1
          fi
        done
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
        echo "Illegal argument. No pattern, sequence or range was specified." >&2
        return 1
      fi
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
  while [ "$#" -gt 0 ] ; do
    if [ "$1" == "list" ] || [ "$1" == "-l" ] ; then
      local records=0; local line_count=$(wc -l < "${_F_LIST}")
      if [ -f "${_F_LIST}" ] && [[ "${line_count}" -gt 0 ]] ; then
        cat -n "${_F_LIST}" ;
      fi
      return $?
    elif ( [ "$1" == "clear" ] || [ "$1" == "-c" ] ) ; then
      > "${_F_LIST}" ;
      return $?
    elif ( [ "$1" == "select" ] || [ "$1" == "-s" ] ) ; then
      local file="${2}" ; local index=0
      if   [ -z "${file}" ] ; then
        echo "Illegal argument." >&2 && return 1;
      fi
      if ! [ -f "${file}" ] ; then
        echo "File does not exist." >&2 && return 1;
      fi
      # Resolve relative path
      if ! [[ "${file}" = /* ]] ; then
        file="`pwd`/${file}"
      fi

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
      return $?
    elif ( [ "$1" == "unselect" ] || [ "$1" == "-u" ] ) ; then
      shift 1; local selected_files=$(print_selected_files_from_list $1)
      while read -r index file ; do
        sed -e "${index}d" "${_F_LIST}" > "${_F_LIST}.tmp" &&
        mv "${_F_LIST}.tmp"  "${_F_LIST}" &&
        print_entry "${index}" "${file}"
      done <<< "${selected_files}"
      return $?
    elif ( [ "$1" == "get" ] || [ "$1" == "-g" ] ) ; then
      # Temporary store selected files.
      shift 1 ; _SELECTED_FILES=$(print_selected_files_from_list $1) ; shift 1 ;
    elif [ "$1" == "-exec" ] ; then
      shift 1 ; local cmd="" ;
      local cmd_terminated=false ; local cmd_params=0 ;

      # Fetch -exec <cmd> until termination-symbol '\;'.
      while [ "$#" -gt 0 ] ; do
        if [ "${1}" == "\;" ] ; then
          cmd_terminated=true; shift 1
          break;
        elif [ "${1}" == "{}" ] ; then
          cmd_params=$((cmd_params+ 1))
        fi
        cmd="${cmd} ${1}"; shift 1;
      done

      # The command-string must meet following constraints.
      if ! [[ ${cmd_terminated} ]] ; then
        echo "Illegal command-string. No termination-symbol '\;' found." >&2
        return 1;
      elif [[ ${cmd_params} -ne 1 ]] && [[ ${cmd_params} -ne 2 ]] ; then
        echo "Illegal command-string. Must contain one or max two params '{}'."
        return 1;
      fi

      # Temporary store command-string.
      _CMD=${cmd}
    else
      local target="$1"; shift 1;
      if ( [ -z "${target}" ] || ! [ -d "${target}" ] ) ; then
        echo "Usage: f [-adl] [args]" && return 1
      fi
      _TARGET=${target}
    fi
  done

  # We only are getting this far when the -g and/or -exec parameter was used.
  if [ -z "${_CMD}" ] ; then
    echo "No command-string was specifed." >&2 && return 1;
  fi
  if [ -z "${_SELECTED_FILES}" ] ; 	then
    echo "No files selected." >&2 && return 1;
  fi

  echo ${_SELECTED_FILES[@]} | while read line; do
    local file=$(echo ${line} | gawk -F " " '{print $2}')  # parse the filename.
    echo LINE $line CMD $_CMD FILE $file
    local cmd=$(echo ${_CMD})
    local cmd=$(echo ${cmd} | sed -e "s#{}#${file}#")	  	# replace first {} with <file>.
    local cmd=$(echo ${cmd} | sed -e "s#{}#${_TARGET}#")	# replace second {} with <target>.
    if "${_DRY}" ; then
      echo ${cmd}
    else
      echo "eval"
      #eval "${cmd}"
    fi
  done
}
f $@
