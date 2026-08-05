# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7

DESCRIPTION="Virtual for Linux kernel headers"
HOMEPAGE="https://kernel.org"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
RDEPEND="!<sys-kernel/linux-headers-6.12-r1
	
"
DEPEND="${RDEPEND}
"
PDEPEND="|| (
	  >=sys-kernel/debian-headers-6.12-r1
	  >=sys-kernel/vanilla-headers-6.12-r1
	)
	
"

# vim: filetype=ebuild
