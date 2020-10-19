#!/bin/sh
DEBUG="${DEBUG:-false}"
VERBOSE="${VERBOSE:-0}"
COLORS="${COLORS:-true}"

if ${COLORS}; then

fi

usage() {
  exec >&2
  printf "${ylw}Usage${nrm} : ${wht}$(basename "${0}")${nrm} [${wht}options${nrm}] shpkgbuild_script\n"
  printf "  build a package from sources\n"
  printf "${wht}options${nrm} :\n"
  printf "  -v : increase verbosity level\n"
  printf "  -d : enable debug mode\n"
  printf "  -h : display this help message\n"
  exit 1
}

error()   { printf "[${red}ERR${nrm}] : ${1}\n" >&2; [ ${2} -gt 0 ] 2>/dev/null && exit ${2}; return 0; }
message() { printf "[${wht}MSG${nrm}] : ${1}\n" >&2; }
warning() { [ ${VERBOSE} -ge 1 ] || return 0; printf "[${red}WRN${nrm}] : ${1}\n" >&2; }
debug()   { [ ${VERBOSE} -ge 2 ] || return 0; printf "[${ylw}DBG${nrm}] : ${1}\n" >&2; }

yesno() {
  local question="${1}" default="${2}" prompt d a
  case "${default}" in
    y|Y) d=0; prompt="([${grn}y${nrm}]/${red}n${nrm})";;
    n|N) d=1; prompt="(${grn}y${nrm}|[${red}n${nrm}])";;
    *)   d=""; prompt="(${grn}y${nrm}/${red}n${nrm})";;
  esac
  while true; do
    printf "${ylw}>${nrm} ${question} ${prompt} " >&2
    read -n1 a
    case "${a}" in
      y|Y) return 0;;
      n|N) return 1;;
      "")  [ ${d} -ge 0 ] 2>/dev/null && return ${d};;
    esac
    printf "  ${red}>>${nrm} please answer with 'y' or 'n'\n" >&2
    sleep 2
  done
}

while getopts vdh opt; do case "${opt}" in
  v) VERBOSE="$(expr ${VERBOSE} + 1)";;
  d) DEBUG="true";;
  *) usage;;
esac; done
shift $(expr ${OPTIND} - 1)
[ -n "${1}" ] || usage
BUILDSCRIPT="$(realpath "${1}")"
