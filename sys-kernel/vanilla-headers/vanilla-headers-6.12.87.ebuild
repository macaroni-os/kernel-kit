# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
inherit eutils toolchain-funcs

DESCRIPTION="Linux kernel header files"
HOMEPAGE="https://kernel.org"
SRC_URI="https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/linux-6.12.87.tar.xz -> linux-6.12.87.tar.xz"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
PATCHES=(
	"${FILESDIR}/00_all_0002-x86-do-not-build-relocs-tool-when-installing-headers.patch"
)
RESTRICT="binchecks strip"
BDEPEND="app-arch/xz-utils
	dev-lang/perl
	net-misc/rsync
	!<sys-kernel/linux-headers-6.12
	!!sys-kernel/debian-headers
	
"
S="${WORKDIR}/linux-${PV}"
pkg_setup() {
	export REAL_ARCH="$ARCH"
	# will interfere with Makefile if set
	unset ARCH; unset LDFLAGS
}
src_prepare() {
	default
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
