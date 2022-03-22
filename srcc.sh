#!/bin/sh
VERBOSE="${VERBOSE:-0}"
DEBUG="${DEBUG:-false}"

SRCC_BASEDIR="$(dirname "$(realpath "${0}")")"
SRCC_CONFFILES="/etc/srcc.conf ${SRCC_BASEDIR}/srcc.conf ${HOME}/.srcc.conf srcc.conf"
SRCC_SHAREDIR="${SRCC_SHAREDIR:-${SRCC_BASEDIR}/share}"

red='\e[1;31m'; grn='\e[1;32m'; ylw='\e[1;33m'; blu='\e[1;34m'
mgt='\e[1;35m'; cyn='\e[1;36m'; wht='\e[1;37m'; nrm='\e[0m'
min_width="80"; max_width="120"

s_width="$(stty size | awk '{print $2}')"
if [ ${s_width} -lt ${min_width} ] 2>/dev/null; then s_width=${min_width}
else
  if [ ${s_width} -gt ${max_width} ] 2>/dev/null; then s_width=${max_width}
  else s_width="${min_width}"; fi
fi

srcc_msg() {
  local lv="${1}" prefix="${2}" c="${3}"
  [ ${lv} -gt ${VERBOSE} ] && return 0
  shift 3
  eval printf \"%s [${c}%3s${nrm}] %s\\n\" \"$(date "+%Y-%m-%d %H:%M:%S")\" \"${prefix}\" \"$@\"
}
error()   { srcc_msg 0 ERR "${red}" "$1" >&2; [ ${2} -ge 0 ] 2>/dev/null && exit ${2}; }
warning() { srcc_msg 1 WRN "${ylw}" "$@" >&2; }
debug()   { srcc_msg 2 DBG "${wht}" "$@" >&2; }
notice()  { srcc_msg 2 NTE "${mgt}" "$@" >&2; }
message() { srcc_msg 0 MSG "${grn}" "$@"; }
info()    { srcc_msg 1 NFO "${cyn}" "$@"; }

s_begin()   { local w=$(expr ${s_width} - 7); printf "${grn}*${nrm} %-${w}s " "${1}"; }
s_end()     { local e=$?; if [ ${e} -eq 0 ]; then printf "${blu}[${grn}ok${blu}]${nrm}\n"; else printf "${blu}[${red}ee${blu}]${nrm}\n"; fi; return ${e}; }
s_message() { local msg="${1}" l i; l="$(printf "${msg}\n" | wc -c)"; for i in $(seq ${l}); do printf "\b"; done; printf "${ylw}${msg}${nrm} "; }

usage() {
  exec >&2
  [ -n "${1}" ] && printf "Error : ${1}\n"
  printf "Usage : $(basename "${0}") [options] receipe.rcp\n"
  printf "  Build/Compile from sources according to provided receipe\n"
  printf "Options :\n"
  printf "  -v : increase verbosity level\n"
  printf "  -d : enable debug mode\n"
  printf "  -h : display this help message\n"
  exit 1
}

srcc_dircheck() {
  local d="${1}" mode="${2}" owner="${3}" group="${4}"
  debug "srcc_dircheck($@)"
  if [ -d "${d}" ]; then
    local e="" v
    if [ -n "${mode}" ]; then
      v="$(stat -c "%a" "${d}")"; [ "${v}" = "${mode}" ] || e="${e}, mode ${v} (instead of ${mode})"
      v="$(stat -c "%U" "${d}")"; [ "${v}" = "${owner}" ] || e="${e}, owner ${v} (instead of ${owner})"
      v="$(stat -c "%G" "${d}")"; [ "${v}" = "${group}" ] || e="${e}, owner ${v} (instead of ${group})"
    fi
    if [ -n "${e}" ]; then warning "srcc_dircheck('${d}') ${e}"
    else debug "srcc_dircheck('${d}') dir exists ok"; fi
    return 0
  else
    if [ -n "${mode}" ]; then
      local opts="-d -m${mode}"
      [ -n "${owner}" ] && opts="${opts} -o${owner}"
      [ -n "${group}" ] && opts="${opts} -g${group}"
      warning "srcc_dircheck('${d}') install ${opts}"
      install ${opts} "${d}"
      return $?
    else
      error "srcc_dircheck('${d}') no such directory..."
      return 1
    fi
  fi
}

srcc_pkgcheck() {
  local bin="${1}" req="${2:-false}" p
  debug "srcc_pkgcheck($@)"
  IFS=":" for p in ${PATH}; do
    [ -x "${p}/${bin}" ] && { debug "srcc_pkgcheck($bin) found -> ${p}/${bin}"; return 0; }
  done
  ${req} || { warning "srcc_pkgcheck($bin) not found in \${PATH} (${PATH})"; return 0; }
  error "srcc_pkgcheck($bin) not found in \${PATH} (${PATH})"
  return 1
}


for f in ${SRCC_CONFFILES}; do
  [ -e "${f}" ] || continue
  debug "loading configuration from '${f}'"
  . "${f}"
done

for f in ${SRCC_SHAREDIR}/*.sh; do
  [ -e "${f}" ] || continue
  debug "loading shared file '${f}'"
done

SRCC_SRCDIR="${SRCC_SRCDIR:-${BASEDIR}/sources}"
SRCC_BUILDDIR="${SRCC_BUILDDIR:-${BASEDIR}/build}"
SRCC_TMPDIR="${SRCC_TMPDIR:-${BASEDIR}/tmp}"
SRCC_PKGDIR="${SRCC_PKGDIR:-${BASEDIR}/packages}"
for d in SRCDIR BUILDDIR TMPDIR PKGDIR; do
  eval k=\"\${SRCC_${d}}\"
  srcc_dircheck "${k}" && debug "$(printf "%-24s is %s\n" "SRCC_${d}" "${k}")"
done

SRCC_BINDEPS_REQ="awk curl sed tar"
for p in ${SRCC_BINDEPS_REQ}; do eval srcc_pkgcheck "${p}" true; done
SRCC_BINDEPS_OPT="unzip"
for p in ${SRCC_BINDEPS_OPT}; do eval srcc_pkgcheck "${p}" false; done

while getopts dvh opt; do case "${opt}" in
  d) DEBUG=true;;
  v) VERBOSE="$(expr ${VERBOSE} + 1)";;
  *) usage;;
esac; done
shift $(expr ${OPTIND} - 1)
[ -n "${1}" ] || usage
[ -e "${1}" ] || usage
RECEIPE="${1}"

