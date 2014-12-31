#!/bin/bash
# @name:        f.sh
# @version:     0.69
# @description: file-operation toolkit.
# @author:      rednammoc
# @date:        14/12/31
# @todo:        unselect/exec by name does not work when its not in the current folder.

# INSTALL: mv to /usr/bin/f or add f-location into PATH.

# Default configuration-file
_F_CONFIG="${HOME}/.config/f/f.conf"

f () {
  # Setup and/or load configuration.
  local _F_CONFIG_DIR=$(dirname "${_F_CONFIG}")
  ! [ -d "${_F_CONFIG_DIR}" ] && mkdir -p "${_F_CONFIG_DIR}"
  if ! [ -f "${_F_CONFIG}" ] ; then
    echo "_F_LIST=\"${_F_CONFIG_DIR}/f.list\""  >> "${_F_CONFIG}"
    echo "_F_DRY=\"false\""                     >> "${_F_CONFIG}"
  fi
  source "${_F_CONFIG}"

  # Initialize local variables.
  local _CMD=""		          # cmd executed by the user. when empty no cmd is executed.
  local _TARGET="${PWD}/"	  # target used as second parameter in cmd-string. default = current directory.
  local _SELECTED_FILES=()	# contains selected files by the get-command.

  # Check that index is 1 <= x <= size(list)
  is_index_within_list () {
    local index="${1}" ; local line_count=$(wc -l < "${_F_LIST}") ;
    is_numeric "${index}" && [ "${index}" -le ${line_count} ]
  }

  # Check that input is numeric.
  is_numeric () {
    [[ "${1}" =~ ^[1-9][0-9]*$ ]]
  }

  # Resolve relative paths.
  resolve_path () {
    local file=${1}
    if ! [[ "${file}" = /* ]] ; then
      file="`pwd`/${file}"
    fi
    echo ${file}
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
  #  <file>     = <absolute-filepath> || <relative-filepath>
  #  <files>    = <file>,<file>, ... <file>
  #  <pattern>  = <sequence> || <range> || 'all'
  #  <index>    = [1-9][0-9]
  #  <sequence> = <index>,<index>, ... <index>
  #  <range>    = <index>:<index>
  #
  get_files_from_list () {
    while [ "$#" -gt 0 ] ; do
      local ARG="${1}" ; shift 1
      if is_numeric "${ARG}" ; then # <index>
        local index="${ARG}"
        if ! is_index_within_list "${index}" ; then
          echo "Illegal argument. Index out of range." >&2 && return 1
        fi
        print_entry_by_index "${index}" || return 1
      elif [[ "${ARG}" == *,* ]] ; then # <sequence>
        IFS=',' read -ra SEQUENCE <<< "$ARG"
        for value in "${SEQUENCE[@]}"; do
          if is_numeric "${value}" ; then
            local index="${value}"
            if ! is_index_within_list "${index}" ; then
              echo "Illegal argument. Index out of range." >&2 && return 1
            fi
            print_entry_by_index "${index}"
          else
            local entry=$(print_entry_by_name "${value}")
            if [ -n "${entry}" ] ; then
              echo $entry
            else
              echo "Illegal argument. Illegal sequence-pattern." >&2 && return 1
            fi
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
        if [ -f "${ARG}" ] ; then
          local file=$(resolve_path "${ARG}")
          local entry=$(print_entry_by_name "${file}");
          if [ -n "${entry}" ] ; then
            echo ${entry}
          else
            echo "Illegal argument. Pattern didn't match any file." >&2
            return 1
          fi
        else
          echo "Illegal argument. No file, pattern, sequence or range was specified." >&2
          return 1
        fi
      fi
    done
  }

  print_selected_files_from_list () {
    if result=$(get_files_from_list $@) ; then
      printf -- '%s\n' "${result[@]}" | sort -n | uniq
      return 0
    fi
    return 1
  }

  print_entry_by_index () {
    local index="$1" ; local file=$(get_entry "${index}")
    [ -n "${file}" ] && print_entry "${index}" "${file}"
  }

  print_entry_by_name () {
    local file="${1}"
    if [ -f "${_F_LIST}" ] ; then
      if grep -Fxq "${file}" "${_F_LIST}" ; then
        index=`grep -Fxnm 1 "${file}" "${_F_LIST}" | grep -oEi '^[0-9]+'`
        print_entry "${index}" "${file}"
      fi
    fi
  }

  print_entry () {
    local index="$1"; local path="$2"
    printf "%+6s  ${path}\n" "${index}"
  }

  print_usage () {
    echo "Usage: f [-adl] [args]"
  }

  f_list () {
    local records=0; local line_count=$(wc -l < "${_F_LIST}")
    if [ -f "${_F_LIST}" ] && [[ "${line_count}" -gt 0 ]] ; then
      cat -n "${_F_LIST}" ;
    fi
  }

  f_select () {
    while [ "$#" -gt 0 ] ; do
      local file="${1}" ; local index=0 ; shift 1
      if   [ -z "${file}" ] ; then
        echo "Illegal argument." >&2 && return 1;
      fi
      if ! [ -f "${file}" ] ; then
        echo "File does not exist." >&2 && return 1;
      fi
      local file=$(resolve_path "${file}")
      local duplicate=$(print_entry_by_name ${file})
      if [ -n "${duplicate}" ] ; then
        index=$(echo $duplicate | gawk -F " " '{print $1}')
        echo "The file '${file}' is already selected (#${index})." >&2
        return 1
      fi
      # Add file to selection and print result.
      echo "${file}" >> "${_F_LIST}"
      index=$(wc -l < "${_F_LIST}")
      print_entry "${index}" "${file}"
    done
  }

  f_unselect () {
    if selected_files=$(print_selected_files_from_list $@) ; then
      while read -r index file ; do
        sed -e "${index}d" "${_F_LIST}" > "${_F_LIST}.tmp" &&
        mv "${_F_LIST}.tmp"  "${_F_LIST}" &&
        print_entry "${index}" "${file}"
      done <<< "${selected_files[@]}"
    fi
  }

  # When no commands were specified print usage.
  if [ "$#" -eq 0 ] ; then
    print_usage && return 1
  fi

  # Parse/Execute commandline-arguments.
  #  These commands cannot be combined with other commands.
  if [ "$1" == "list" ] || [ "$1" == "-l" ] ; then
    f_list                  ; return $?
  elif ( [ "$1" == "clear" ] || [ "$1" == "-c" ] ) ; then
    > "${_F_LIST}"          ; return $?
  elif ( [ "$1" == "select" ] || [ "$1" == "-s" ] ) ; then
    shift 1 ; f_select $@   ; return $?
  elif ( [ "$1" == "unselect" ] || [ "$1" == "-u" ] ) ; then
    shift 1 ; f_unselect $@ ; return $?
  fi

  # Parse/Execute commandline-arguments.
  #  These commands must be combined.
  while [ "$#" -gt 0 ] ; do
    if [ "$1" == "exec" ] || [ "$1" == "-e" ] ; then
      shift 1 ;
      local cmd="" ;
      local cmd_terminated=false ;
      local cmd_params=0 ;

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
      # Temporary store selected files.
      entry=$(print_selected_files_from_list $1)
      if [ -z "${entry}" ] ; then
        return 1;
      fi
      _SELECTED_FILES+=("${entry}") ;
      shift 1
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
    local cmd=$(echo ${_CMD} | sed -e "s#{}#${file}#")	  	# replace first {} with <file>.
    if [ "${_F_DRY}" == "true" ] ; then
      echo ${cmd}
    else
      eval ${cmd}
    fi
  done
}
f $@
