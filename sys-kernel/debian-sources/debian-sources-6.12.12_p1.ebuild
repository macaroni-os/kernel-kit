# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit check-reqs eutils ego savedconfig

SLOT=trixie/6.12.12_p1

# NOTE: When updating: use the version from Debian testing (trixie)
# https://packages.debian.org/trixie/linux-source
DEB_PATCHLEVEL="1"
KERNEL_TRIPLET="6.12.12"

VERSION_SUFFIX="_p${DEB_PATCHLEVEL}"
if [ ${PR} != "r0" ]; then
	VERSION_SUFFIX+="-${PR}"
fi
# like "6.1.99_p1-r1-debian-sources"
EXTRAVERSION="${VERSION_SUFFIX}-${PN}"
MOD_DIR_NAME="${KERNEL_TRIPLET}${EXTRAVERSION}"
# install sources to /usr/src/$LINUX_SRCDIR
LINUX_SRCDIR=linux-${PF}
DEB_PV="${KERNEL_TRIPLET}-${DEB_PATCHLEVEL}"


RESTRICT="binchecks strip"
LICENSE="GPL-2"
KEYWORDS="*"
IUSE="acpi-ec binary btrfs custom-cflags ec2 genkernel +logo luks lvm mdadm ramdisk savedconfig sshd sign-modules zfs"
RDEPEND="
	|| (
		<sys-apps/gawk-5.2.0
		>=sys-apps/gawk-5.2.1
	)
	ramdisk? ( >=sys-apps/ramdisk-1.1.3 )
	genkernel? ( >=sys-kernel/genkernel-4.3.10-r3 )
"
DEPEND="
	virtual/libelf
	btrfs? ( sys-fs/btrfs-progs )
	zfs? ( sys-fs/zfs )
	luks? ( sys-fs/cryptsetup )
	lvm? ( sys-fs/lvm2 )"
REQUIRED_USE="
	binary? (
		^^ ( ramdisk genkernel )
		btrfs? ( genkernel )
		mdadm? ( genkernel )
		luks? ( genkernel )
		lvm? ( genkernel )
		sshd? ( genkernel )
	)
	ramdisk? ( !genkernel )
"

DESCRIPTION="Debian Sources (and optional binary kernel)"
DEB_UPSTREAM="http://http.debian.net/debian/pool/main/l/linux"
HOMEPAGE="https://packages.debian.org/unstable/kernel/"
SRC_URI="https://build.funtoo.org/distfiles/debian-sources/debian-sources-6.3.7_p1-rtw89-driver.tar.gz -> debian-sources-6.3.7_p1-rtw89-driver.tar.gz
https://deb.debian.org/debian/pool/main/l/linux/linux_6.12.12-1.debian.tar.xz -> linux_6.12.12-1.debian.tar.xz
https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/linux-6.12.12.tar.xz -> linux-6.12.12.tar.xz"
S="$WORKDIR/linux-${KERNEL_TRIPLET}"

get_patch_list() {
	[[ -z "${1}" ]] && die "No patch series file specified"
	local patch_series="${1}"
	while read line ; do
		if [[ "${line:0:1}" != "#" ]] ; then
			echo "${line}"
		fi
	done < "${patch_series}"
}

tweak_config() {
	einfo "Setting $2=$3 in kernel config."
	sed -i -e "/^$2=/d" $1
	echo "$2=$3" >> $1
}

setno_config() {
	einfo "Setting $2*=y to n in kernel config."
	sed -i -e "s/^$2\(.*\)=.*/$2\1=n/g" $1
}

setyes_config() {
	einfo "Setting $2*=* to y in kernel config."
	sed -i -e "s/^$2\(.*\)=.*/$2\1=y/g" $1
}

zap_config() {
	einfo "Removing *$2* from kernel config."
	sed -i -e "/$2/d" $1
}

get_vendor() {
	vendor_string=$(grep vendor /proc/cpuinfo | uniq | cut -d ':' -f 2)
	vendor=$([[ ${vendor_string^^} =~ (INTEL)|(AMD) ]] && echo ${BASH_REMATCH[0]})
	echo $vendor
}

pkg_pretend() {
	# Ensure we have enough disk space to compile
	if use binary ; then
		CHECKREQS_DISK_BUILD="6G"
		check-reqs_pkg_setup
		echo "binary"
	fi
}

get_certs_dir() {
	# find a certificate dir in /etc/kernel/certs/ that contains signing cert for modules.
	for subdir in $PF $P linux; do
		certdir=/etc/kernel/certs/$subdir
		if [ -d $certdir ]; then
			if [ ! -e $certdir/signing_key.pem ]; then
				eerror "$certdir exists but missing signing key; exiting."
				exit 1
			fi
			echo $certdir
			return
		fi
	done
}

pkg_setup() {
	export REAL_ARCH="$ARCH"
	unset ARCH; unset LDFLAGS #will interfere with Makefile if set
	export FEATURESET="standard"
}

src_prepare() {
	default
	for debpatch in $( get_patch_list "${WORKDIR}/debian/patches/series" ); do
		epatch -p1 "${WORKDIR}/debian/patches/${debpatch}"
	done
	# end of debian-specific stuff...

	# do not include debian devs certificates
	rm -rf "${WORKDIR}"/debian/certs

	# remove references to debian uefi certs
	sed -i -e 's|\${CURDIR}\/debian\/certs\/debian-uefi-certs\.pem||g' "${WORKDIR}"/debian/rules.gen

	sed -i -e "s:^\(EXTRAVERSION =\).*:\1 ${EXTRAVERSION}:" Makefile || die
	sed	-i -e 's:#export\tINSTALL_PATH:export\tINSTALL_PATH:' Makefile || die
	rm -f .config >/dev/null
	cp -a "${WORKDIR}"/debian "${T}"
	make -s mrproper || die "make mrproper failed"
	cd "${S}" || die
	cp -aR "${WORKDIR}"/debian "${S}"/debian
	epatch "${FILESDIR}"/latest/ikconfig.patch || die
	epatch "${FILESDIR}"/latest/mcelog.patch || die
	epatch "${FILESDIR}"/6.8+/more-uarches-for-kernel-6.8-rc4+.patch || die
	# revert recent changes to the rtw89 driver that cause problems for Wi-Fi:
	rm -rf "${S}"/drivers/net/wireless/rtw89 || die
	tar xzf "${DISTDIR}"/debian-sources-6.3.7_p1-rtw89-driver.tar.gz -C "${S}"/drivers/net/wireless/ || die
	einfo "Using debian-sources-6.3.7_p1 Wi-Fi driver to avoid latency issues..."
	if use savedconfig; then
		einfo Restoring saved .config ...
		restore_config .config
	else
		cp "${FILESDIR}"/config-extract-6.6 ./config-extract || die
		chmod +x config-extract || die
	fi
	# Set up arch-specific variables and this will fail if run in pkg_setup() since ARCH can be unset there:
	if [ "${REAL_ARCH}" = x86 ]; then
		export DEB_ARCH="i386"
		export DEB_SUBARCH="686-pae"
		export KERN_SUFFIX="${PN}-i686-${PV}"
	elif [ "${REAL_ARCH}" = amd64 ]; then
		export DEB_ARCH="amd64"
		export DEB_SUBARCH="amd64"
		export KERN_SUFFIX="${PN}-x86_64-${PV}"
	else
		die "Architecture '${REAL_ARCH}' not handled in ebuild"
	fi
	[[ ${PR} != "r0" ]] && KERN_SUFFIX+="-${PR}"

	if ! use savedconfig; then
		./config-extract ${DEB_ARCH} ${FEATURESET} ${DEB_SUBARCH} || die
	fi
	setno_config .config CONFIG_DEBUG
	if use acpi-ec; then
		# most fan control tools require this
		tweak_config .config CONFIG_ACPI_EC_DEBUGFS m
		tweak_config .config CONFIG_DEBUG_FS y
	fi
	if use ec2; then
		setyes_config .config CONFIG_BLK_DEV_NVME
		setyes_config .config CONFIG_XEN_BLKDEV_FRONTEND
		setyes_config .config CONFIG_XEN_BLKDEV_BACKEND
		setyes_config .config CONFIG_IXGBEVF
	fi
	if use logo; then
		epatch "${FILESDIR}"/latest/funtoo_logo.patch || die
		tweak_config .config CONFIG_LOGO y
		ewarn "Linux kernel frame buffer boot logo is now enabled with a custom Funtoo pixmap."
		ewarn "The new logo can be viewed at /usr/src/linux/drivers/video/logo/logo_linux_clut224.ppm"
		ewarn "Remove the quiet kernel parameter (from params in /etc/boot.conf, and re-run boot-update.)"
		ewarn "This will ensure the custom kernel logo is displayed during boot over frame buffer."
		ewarn ""
	fi
	if use sign-modules; then
		certs_dir=$(get_certs_dir)
		echo
		if [ -z "$certs_dir" ]; then
			eerror "No certs dir found in /etc/kernel/certs; aborting."
			die
		else
			einfo "Using certificate directory of $certs_dir for kernel module signing."
		fi
		echo
		# turn on options for signing modules.
		# first, remove existing configs and comments:
		zap_config .config CONFIG_MODULE_SIG
		# now add our settings:
		tweak_config .config CONFIG_MODULE_SIG y
		tweak_config .config CONFIG_MODULE_SIG_FORCE n
		tweak_config .config CONFIG_MODULE_SIG_ALL n
		tweak_config .config CONFIG_MODULE_SIG_HASH \"sha512\"
		tweak_config .config CONFIG_MODULE_SIG_KEY  \"${certs_dir}/signing_key.pem\"
		tweak_config .config CONFIG_SYSTEM_TRUSTED_KEYRING y
		tweak_config .config CONFIG_SYSTEM_EXTRA_CERTIFICATE y
		tweak_config .config CONFIG_SYSTEM_EXTRA_CERTIFICATE_SIZE 4096
		echo "CONFIG_MODULE_SIG_SHA512=y" >> .config
		ewarn "This kernel will ALLOW non-signed modules to be loaded with a WARNING."
		ewarn "To enable strict enforcement, YOU MUST add module.sig_enforce=1 as a kernel boot"
		ewarn "parameter (to params in /etc/boot.conf, and re-run boot-update.)"
		ewarn ""
	else
		tweak_config .config CONFIG_MODULE_SIG n
	fi
	if use custom-cflags; then
		MARCH="$(python3 -c "import portage; print(portage.settings[\"CFLAGS\"])" | sed 's/ /\n/g' | grep "march")"

		if [ -n "$MARCH" ]; then
			if [[ $MARCH =~ (native) ]] && [[ -n $(get_vendor) ]]; then
				einfo "Detected -march=native on $(get_vendor)"
				CONFIG_MARCH=CONFIG_MNATIVE_$(get_vendor)
			else
				CONFIG_MARCH="$(grep -m 1 -e "${MARCH}" -B 1 arch/x86/Makefile | sort -r | grep -m 1 -o CONFIG_\[^\)\]* )"
			fi

			if [ -n "${CONFIG_MARCH}" ]; then
				einfo "Optimizing kernel for ${CONFIG_MARCH}"
				tweak_config .config CONFIG_GENERIC_CPU n
				tweak_config .config "${CONFIG_MARCH}" y
			else
				ewarn "Could not find optimized settings for $MARCH, compiling generic kernel."
			fi
		fi
	fi
	# build generic CRC32C module into kernel, to defeat FL-11913
	# (cannot mount ext4 filesystem in initramfs if created with recent e2fsprogs version)
	tweak_config .config CONFIG_CRYPTO_CRC32C y

	# disable module compression until the initramfs plays nicely with it
	tweak_config .config CONFIG_MODULE_COMPRESS_XZ n
	tweak_config .config CONFIG_MODULE_COMPRESS_NONE y

	# get config into good state:
	yes "" | make oldconfig >/dev/null 2>&1 || die
	cp .config "${T}"/config || die
	make -s mrproper || die "make mrproper failed"
}

src_compile() {
	! use binary && return
	install -d "${WORKDIR}"/build
	cp "${T}"/config "${WORKDIR}"/build/.config || die "couldn't copy kernel config"
	make ${MAKEOPTS} O="${WORKDIR}"/build bzImage || die "kernel build failure"
	make ${MAKEOPTS} O="${WORKDIR}"/build modules || die "modules build failure"
}

src_install() {
	# copy sources into place:
	dodir /usr/src
	cp -a "${S}" "${D}"/usr/src/${LINUX_SRCDIR} || die
	cd "${D}"/usr/src/${LINUX_SRCDIR}
	# prepare for real-world use and 3rd-party module building:
	make mrproper || die
	cp "${T}"/config .config || die
	cp -a "${T}"/debian debian || die

	# if we didn't compile a kernel, we're done. The kernel source tree is left in
	# an unconfigured state - you can't compile 3rd-party modules against it yet.
	use binary || return
	make ${MAKEOPTS} O="${WORKDIR}"/build INSTALL_MOD_PATH="${D}" modules_install || die "modules install failure"
	insinto /boot
	newins ${WORKDIR}/build/arch/x86/boot/bzImage "kernel-${KERN_SUFFIX}.tmp"
	newins ${WORKDIR}/build/System.map "System.map-${KERN_SUFFIX}.tmp"
	newins ${WORKDIR}/build/.config "config-${KERN_SUFFIX}.tmp"
	make prepare || die
	make scripts || die
	# FL-8004: In Linux 5.10, module.lds is generated by 'modules_prepare',
	# so we need to run it as well to be able to compile modules
	make modules_prepare || die

	# module symlink fixup:
	rm -f "${D}"/lib/modules/*/source || die
	rm -f "${D}"/lib/modules/*/build || die
	cd "${D}"/lib/modules
	local moddir="$(ls -d [1-9]*)"
	ln -s /usr/src/${LINUX_SRCDIR} "${D}"/lib/modules/${moddir}/source || die
	ln -s /usr/src/${LINUX_SRCDIR} "${D}"/lib/modules/${moddir}/build || die
	# Fixes FL-14
	cp "${WORKDIR}/build/System.map" "${D}/usr/src/${LINUX_SRCDIR}/" || die
	cp "${WORKDIR}/build/Module.symvers" "${D}/usr/src/${LINUX_SRCDIR}/" || die
	if use sign-modules; then
		# TODO FIXME: check for compressed modules.
		find "${D}"/lib/modules -iname *.ko -exec ${WORKDIR}/build/scripts/sign-file sha512 $certs_dir/signing_key.pem $certs_dir/signing_key.x509 {} \; || die
		# install the sign-file executable for future use.
		exeinto /usr/src/${LINUX_SRCDIR}/scripts
		doexe ${WORKDIR}/build/scripts/sign-file
	fi
	use ramdisk && ! use genkernel && ( \
		/usr/bin/ramdisk \
			--fs_root="${D}" \
			--temp_root="${T}" \
			--kernel=${MOD_DIR_NAME} \
			--keep \
			 ${D}/boot/initramfs-${KERN_SUFFIX}.tmp --debug --backtrace || \
				die "ramdisk failed: $?" \
	)
	! use ramdisk && use genkernel && ( \
		addread /var/cache/genkernel;
		addwrite /var/cache/genkernel;
		/usr/bin/genkernel initramfs \
			--no-mrproper \
			--no-clean \
			--no-sandbox \
			$(use lvm && echo --lvm) \
			$(use luks && echo --luks) \
			$(use mdadm && echo --mdadm) \
			$(use btrfs && echo --btrfs) \
			$(use sshd && echo --ssh) \
			--logfile=$WORKDIR/genkernel.log \
			--kerneldir=${D}/usr/src/${LINUX_SRCDIR}/ \
			--bootdir=${D}/boot \
			--no-clear-cachedir \
			--kernel-modules-prefix=${D} \
			--ramdisk-modules \
			--initramfs-filename=initramfs-${KERN_SUFFIX}.tmp || \
				die "genkernel failed:  $?" \
	)
	# The following line associates the .tmp dir with this package, so that
	# when the package is uninstalled, the modules are not removed.
	# Otherwise, modules for the current running kernel might be erased!
	mv "${D}"/lib/modules/${MOD_DIR_NAME}{,.tmp}
}

pkg_postinst() {
	# Ensure that /boot is mounted in this phase
	ego_pkg_preinst

	# Prevent kernel, initramfs, and modules erasure during upgrade.
	if use binary; then
		for i in {kernel,initramfs,System.map,config}; do
			if [[ -f "/boot/$i-${KERN_SUFFIX}" ]]; then
				# USE=savedconfig means the config might have changed!
				# In that case, keep the old kernel around, for safety.
				if use savedconfig; then
					[[ -f "/boot/$-${KERN_SUFFIX}.old" ]] && \
						rm /boot/$i-${KERN_SUFFIX}.old
					einfo "Preserving: mv /boot/$i-${KERN_SUFFIX}{,.old}"
					mv /boot/$i-${KERN_SUFFIX}{,.old} || die
				else
					rm /boot/$i-${KERN_SUFFIX} || die
				fi
			fi
			mv /boot/$i-${KERN_SUFFIX}{.tmp,} || die
		done
		if [[ -d "/lib/modules/${MOD_DIR_NAME}" ]]; then
			# USE=savedconfig means the config might have changed!
			# In that case, keep the old modules around, for safety.
			if use savedconfig; then
				[[ -d "/lib/modules/${MOD_DIR_NAME}.old" ]] && \
					rm -r /lib/modules/${MOD_DIR_NAME}.old
				einfo "Preserving: mv /lib/modules/${MOD_DIR_NAME}{,.old}"
				mv /lib/modules/${MOD_DIR_NAME}{,.old} || die
			else
				rm -r /lib/modules/${MOD_DIR_NAME} || die
			fi
		fi
		mv /lib/modules/${MOD_DIR_NAME}{.tmp,} || die
	fi

	if use binary && [[ -h "${ROOT}"usr/src/linux ]]; then
		rm "${ROOT}"usr/src/linux || die
	fi

	if use binary && [[ ! -e "${ROOT}"usr/src/linux ]]; then
		ewarn "With binary use flag enabled /usr/src/linux"
		ewarn "symlink automatically set to debian kernel"
		ewarn "If you have external modules, don't forget to rebuild them with:"
		ewarn ""
		ewarn "  emerge @module-rebuild"
		ewarn ""
		ln -sf ${LINUX_SRCDIR} "${ROOT}"usr/src/linux || die
	fi

	if [ -e ${ROOT}lib/modules ]; then
		depmod -a $MOD_DIR_NAME || die
	fi

	# Update bootloader and unmount /boot
	ego_pkg_postinst
}

# vim: syn=ebuild noet ts=4