# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
inherit eutils toolchain-funcs

DESCRIPTION="Linux kernel header files with Debian patches"
HOMEPAGE="https://kernel.org https://debian.org/kernel"
SRC_URI="
https://deb.debian.org/debian/pool/main/l/linux/linux_6.12.95-1.debian.tar.xz -> linux_6.12.95-1.debian.tar.xz
https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/linux-6.12.95.tar.xz -> linux-6.12.95.tar.xz"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
PATCHES=(
	"${FILESDIR}/00_all_0002-x86-do-not-build-relocs-tool-when-installing-headers.patch"
)
BDEPEND="app-arch/xz-utils
	dev-lang/perl
	net-misc/rsync
	!!sys-kernel/vanilla-headers
	
"
S="${WORKDIR}/linux-${PV%%_p*}"
get_patch_list() {
	[[ -z "${1}" ]] && die "No patch series file specified"
	local patch_series="${1}"
	while read line ; do
	  if [[ "${line:0:1}" != "#" ]] ; then
	    echo "${line}"
	  fi
	done < "${patch_series}"
}
pkg_setup() {
	# will interfere with Makefile if set
	unset ARCH; unset LDFLAGS
}
src_prepare() {
	default
	# apply debian patchset
	for debpatch in $( get_patch_list "${WORKDIR}/debian/patches/series" ); do
	  eapply -p1 "${WORKDIR}/debian/patches/${debpatch}" || die "could not apply patch!"
	done
	# drop unused errno.h include
	sed -e '/^#include <errno.h>/d' -i ${S}/scripts/unifdef.c
}
src_compile() {
	:
}
src_install() {
	# fix permissions in source tree
	cd "${WORKDIR}"
	chown -R 0:0 * >& /dev/null
	chmod -R a+r-w+X,u+w *
	cd "${OLDPWD}"
	[[ -L /usr/include/linux ]] && { rm /usr/include/linux || die; }
	[[ -L /usr/include/asm ]] && { rm /usr/include/asm || die; }
	emake O="${D}" ARCH="$(tc-arch-kernel)" headers_install \
	  || die "could not install headers to image"
	# prune non-headers from tree
	rm "${D}"/{arch,include,scripts} -r
	find "${D}" '(' -name '.install' -o -name '*.cmd' ')' -delete
}


# vim: filetype=ebuild
