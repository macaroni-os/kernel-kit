# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7

DESCRIPTION="A virtual package that installs a Dracut config for MARK"
SLOT="0"
KEYWORDS="*"
S="${WORKDIR}"
src_install() {
	insinto /etc/dracut.conf.d/
	newins ${FILESDIR}/dracut-mark.conf 99-macaroni.conf
}


# vim: filetype=ebuild
