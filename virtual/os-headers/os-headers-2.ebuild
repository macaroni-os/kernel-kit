# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7

DESCRIPTION="Virtual for operating system headers"
SLOT="0"
KEYWORDS="*"
RDEPEND="|| (
	  sys-kernel/debian-headers
	  sys-kernel/vanilla-headers
	)
	
"
DEPEND="${RDEPEND}
"

# vim: filetype=ebuild
