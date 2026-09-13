# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
inherit autotools flag-o-matic linux-mod toolchain-funcs

DESCRIPTION="OpenZFS on Linux and FreeBSD"
HOMEPAGE="https://openzfs.github.io/openzfs-docs"
SRC_URI="https://api.github.com/repos/openzfs/zfs/tarball/zfs-2.4.4 -> zfs-kmod-2.4.4-71a9f95.tar.gz"
LICENSE="CDDL MIT"
SLOT="0"
KEYWORDS="*"
IUSE="custom-cflags debug +rootfs"
BDEPEND="dev-lang/perl
	virtual/awk
	
"

post_src_unpack() {
	mv openzfs-zfs-* ${S}
}


pkg_setup() {
	linux-info_pkg_setup
}
src_prepare() {
	default
	# Set revision number
	sed -i "s/\(Release:\)\(.*\)1/\1\2${PR}-macaronios/" META || die "Could not set MacaroniOS release"
}
src_configure() {
	set_arch_to_kernel
	 use custom-cflags || strip-flags
	 filter-ldflags -Wl,*
	 ./autogen.sh
	 local myconf=(
	  CROSS_COMPILE="${CHOST}-"
	  HOSTCC="$(tc-getBUILD_CC)"
	  --bindir=/bin
	  --sbindir=/sbin
	  --with-config=kernel
	  --with-linux="${KV_DIR}"
	  --with-linux-obj="${KV_OUT_DIR}"
	  $(use_enable debug)
	)
	 econf "${myconf[@]}"
}
src_compile() {
	set_arch_to_kernel

	myemakeargs=(
		CROSS_COMPILE="${CHOST}-"
		HOSTCC="$(tc-getBUILD_CC)"
		V=1
	)

	emake "${myemakeargs[@]}"
}
src_install() {
	set_arch_to_kernel
	 myemakeargs+=(
	  DEPMOD=/bin/true
	  DESTDIR="${D}"
	)
	 emake "${myemakeargs[@]}" install
	einstalldocs
}
pkg_postinst() {
	linux-mod_pkg_postinst
}



# vim: filetype=ebuild
