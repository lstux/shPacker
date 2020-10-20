#!/bin/sh
for f in /etc/shpkg/build.conf ${HOME}/.shpkg_build.conf ./shpkg_build.conf; do
  [ -e "${f}" ] && source "${f}"
done

SHPKG_DEBUG="${SHPKG_DEBUG:-false}"
SHPKG_VERBOSE="${SHPKG_VERBOSE:-0}"
SHPKG_FORCE_YES="${SHPKG_FORCE_YES:-false}"
SHPKG_COLORS="${SHPKG_COLORS:-true}"

SHPKG_DEBUG_SHELL="${SHPKG_DEBUG_SHELL:-${SHELL:-/bin/sh}}"

SHPKG_DOWNLOAD_DIR="${SHPKG_DOWNLOAD_DIR:-/usr/src}"
SHPKG_BUILD_DIR="${SHPKG_BUILD_DIR:-/usr/src}"
SHPKG_DIST_DIR="${SHPKG_DIST_DIR:-$(pwd)}"


if ${SHPKG_COLORS}; then red='\e[1;31m'; grn='\e[1;32m'; ylw='\e[1;33m'; wht='\e[1;37m'; nrm='\e[0m'
else red=""; grn=""; ylw=""; wht=""; nrm=""; fi

usage() {
  exec >&2
  printf "${ylw}Usage${nrm} : ${wht}$(basename "${0}")${nrm} [${wht}options${nrm}] shpkgbuild_script\n"
  printf "  build a package from sources\n"
  printf "${wht}options${nrm} :\n"
  printf "  -y : answer yes to any question\n"
  printf "  -v : increase verbosity level\n"
  printf "  -d : enable debug mode (implies -vv)\n"
  printf "  -h : display this help message\n"
  exit 1
}

error()   { printf "[${red}ERR${nrm}] : ${1}\n" >&2; [ ${2} -gt 0 ] 2>/dev/null && exit ${2}; return 0; }
message() { printf "[${wht}MSG${nrm}] : ${1}\n"; }
info()    { [ ${SHPKG_VERBOSE} -ge 1 ] || return 0; printf "[${wht}NFO${nrm}] : ${1}\n"; }
warning() { [ ${SHPKG_VERBOSE} -ge 1 ] || return 0; printf "[${red}WRN${nrm}] : ${1}\n" >&2; }
debug()   { [ ${SHPKG_VERBOSE} -ge 2 ] || return 0; printf "[${ylw}DBG${nrm}] : ${1}\n" >&2; }

yesno() {
  local question="${1}" default="${2}" prompt d a
  case "${default}" in
    y|Y|0) d=0; prompt="([${grn}y${nrm}]|${red}n${nrm})";;
    n|N|1) d=1; prompt="(${grn}y${nrm}|[${red}n${nrm}])";;
    *)     d=""; prompt="(${grn}y${nrm}|${red}n${nrm})";;
  esac
  while true; do
    printf "${ylw}>${nrm} ${question} ${prompt} " >&2
    ${SHPKG_FORCE_YES} && { printf "auto-answering '${grn}yes${nrm}'\n" >&2; return 0; }
    read -n1 a
    case "${a}" in
      y|Y) return 0;;
      n|N) return 1;;
      "")  [ ${d} -ge 0 ] 2>/dev/null && return ${d};;
    esac
    printf "  ${red}>>${nrm} please answer with '${grn}y${nrm}' or '${red}n${nrm}'\n" >&2
    sleep 2
  done
}

debug_step() {
  ${SHPKG_DEBUG} || return 0 a
  local stepname="${1}" cdir="${2}"
  while true; do
    printf "${ylw}>${nrm} ${stepname} ([${grn}y${nrm}]|${red}n${nrm}|${ylw}s${nrm}|${red}q${nrm}) " >&2
    read -n1 a
    case "${a}" in
      y|Y|'') [ "${a}" = "" ] || printf "\n" >&2; return 0;;
      n|N)    printf "\n" >&2; return 1;;
      s|S)    printf "\n" >&2; [ -n "${cdir}" ] && cd "${cdir}"; ${SHPKG_DEBUG_SHELL}; continue;;
      q|Q)    printf "\n" >&2; message "aborting on user request"; exit 255;;
      *)      printf "\n  ${red}>>${nrm} please answer with '${grn}y${nrm}' to proceed, '${red}n${nrm}' to skip," >&2
              printf " '${ylw}s${nrm}' to run a shell before continuing or '${red}q${nrm}' to quit\n" >&2
              sleep 2;;
    esac
  done
}

shpkg_fetch() {
  [ -n "${DOWNLOAD_URL}" ] || { debug "no archive to fetch"; return 0; }
  if [ -e "${SHPKG_LOCAL_ARCHIVE}" ]; then
    info "'$(basename "${SHPKG_LOCAL_ARCHIVE}")' already downloaded"
    return 0
  fi
  debug_step "download archive from '${DOWNLOAD_URL}'?" "${SHPKG_DOWNLOAD_DIR}" || return 0
  message "downloading archive from '${DOWNLOAD_URL}'"
  curl -o "${SHPKG_LOCAL_ARCHIVE}" "${DOWNLOAD_URL}" || error "download failed (curl error $?)" 4
}

shpkg_extract() {
  [ -n "${SHPKG_LOCAL_ARCHIVE}" ] || { debug "no archive to extract"; return 0; }
  debug_step "extract '${SHPKG_LOCAL_ARCHIVE}' to '${SHPKG_BUILD_DIR}'?" "${SHPKG_DOWNLOAD_DIR}" || return 0
  message "extracting '$(basename "${SHPKG_LOCAL_ARCHIVE}")' to '${SHPKG_BUILD_DIR}'"
  local taropts="x"
  ${SHPKG_DEBUG} && taropts="${taropts}v"
  case "${SHPKG_LOCAL_ARCHIVE}" in
    *.tar.gz|*.tgz)   taropts="${taropts}zf";;
    *.tar.bz2|*.tbz2) taropts="${taropts}jf";;
    *.tar.xz)         taropts="${taropts}Jf";;
    *.zip)            unzip "${SHPKG_LOCAL_ARCHIVE}" -d "${SHPKG_BUILD_DIR}" || error "failed to unzip local archive (unzip error $?)" 8; return 0;;
    *)                error "unhandled archive format for '$(basename "${SHPKG_LOCAL_ARCHIVE}")'" 8;;
  esac
  tar ${taropts} "${SHPKG_LOCAL_ARCHIVE}" -C "${SHPKG_BUILD_DIR}" || error "failed to extract local archive (tar error $?)" 8
}

while getopts yvdh opt; do case "${opt}" in
  y) SHPKG_FORCE_YES="true";;
  v) SHPKG_VERBOSE="$(expr ${SHPKG_VERBOSE} + 1)";;
  d) SHPKG_DEBUG="true"; [ ${SHPKG_VERBOSE} -lt 2 ] && SHPKG_VERBOSE=2;;
  *) usage;;
esac; done
shift $(expr ${OPTIND} - 1)
[ -n "${1}" ] || usage
BUILDSCRIPT="$(realpath "${1}")"
eval $(sed -n '/^[A-Za-z_][A-Za-z0-9_]*=/p' "${BUILDSCRIPT}")

[ -d "${SHPKG_DOWNLOAD_DIR}" ] || SHPKG_DOWNLOAD_DIR="$(dirname "${BUILDSCRIPT}")"
[ -d "${SHPKG_DIST_DIR}" ] || SHPKG_DIST_DIR="$(dirname "${BUILDSCRIPT}")"
[ -d "${SHPKG_BUILD_DIR}" ] || SHPKG_BUILD_DIR="$(dirname "${BUILDSCRIPT}")"

[ -n "${PKGNAME}" ]     || PKGNAME="$(basename "${BUILDSCRIPT}" | sed 's/^\([^\-]\+\)-.*/\1/')"
[ -n "${PKGVERSION}" ]  || PKGVERSION="$(basename "${BUILDSCRIPT}" | sed 's/^[^\-]\+-\([^\-]\+\)-.*/\1/')"
[ -n "${PKGREVISION}" ] || PKGREVISION="$(basename "${BUILDSCRIPT}" | sed 's/^[^\-]\+-[^\-]\+-\(.\+\)\.[a-zA-Z0-9]\+$/\1/')"
if [ -n "${DOWNLOAD_URL}" ]; then
  eval DOWNLOAD_URL=\"${DOWNLOAD_URL}\"
  SHPKG_LOCAL_ARCHIVE="${SHPKG_DOWNLOAD_DIR}/$(basename "${DOWNLOAD_URL}")"
  SHPKG_SOURCES_DIR="${SHPKG_BUILD_DIR}/${PKGNAME}-${PKGVERSION}"
else
  SHPKG_LOCAL_ARCHIVE=""
  SHPKG_SOURCES_DIR=""
fi

shpkg_fetch
shpkg_extract
source "${BUILDSCRIPT}"
