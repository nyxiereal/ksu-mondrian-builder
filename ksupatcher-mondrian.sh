#!/system/bin/sh

# ─────────────────────────────────────────────
#  KSU / KSUN Boot Patcher — Mondrian (Poco F5 Pro)
#  KMI: android12-5.10 (GKI w/ vendor fragment)
#
#  .ko files:  nyxiereal/ksu-mondrian-builder
#  ksud binary: upstream KSU / KSU-Next
# ─────────────────────────────────────────────

WDIR=$(pwd)
KSUD="ksud-aarch64-linux-android"
KO_REPO="nyxiereal/ksu-mondrian-builder"

# ── Logging helpers ───────────────────────────
log_ok()   { echo -e "\e[1;32m[+]\e[0m $*"; }
log_info() { echo -e "\e[1;34m[*]\e[0m $*"; }
log_err()  { echo -e "\e[1;31m[-]\e[0m $*"; }

die() {
	log_err "$*"
	exit 1
}

fetch_latest_tag() {
	curl -s "https://api.github.com/repos/${1}/releases" \
		| grep -o '"html_url": *"[^"]*"' \
		| sed -E 's/.*\/tag\/([^"]*)".*/\1/' \
		| head -n1
}

# ── Preflight checks ─────────────────────────
if [[ ${WDIR} != /data/local/tmp ]]; then
	die "Script needs to be placed in /data/local/tmp!"
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
	echo -e "\e[1;33mUsage: $0 <ksu|ksun> [ota]\e[0m"
	exit 1
fi

VARIANT=$1
MODE=$2

# ── Resolve variant ──────────────────────────
log_info "Resolving variant: ${VARIANT}"

case $VARIANT in
ksu)
	KSUD_REPO="tiann/KernelSU"
	KSUM="kernelsu.ko"
	;;
ksun)
	KSUD_REPO="KernelSU-Next/KernelSU-Next"
	KSUM="kernelsu_next.ko"
	;;
*)
	die "Unknown variant '${VARIANT}'. Available options: ksu | ksun"
	;;
esac

# ── Fetch latest release tags ─────────────────
log_info "Fetching latest ksud release tag from ${KSUD_REPO}..."
LATEST_KSUD=$(fetch_latest_tag "${KSUD_REPO}")
[[ -z ${LATEST_KSUD} ]] && die "Failed to fetch ksud release tag from ${KSUD_REPO}!"
log_ok "ksud release: ${LATEST_KSUD}"

log_info "Fetching latest .ko release tag from ${KO_REPO}..."
LATEST_KO=$(fetch_latest_tag "${KO_REPO}")
[[ -z ${LATEST_KO} ]] && die "Failed to fetch .ko release tag from ${KO_REPO}!"
log_ok ".ko release: ${LATEST_KO}"

log_info "Fetching latest magiskboot release tag..."
LATESTMBOOT=$(fetch_latest_tag "cyberknight777/magisk_bins_ndk")
[[ -z ${LATESTMBOOT} ]] && die "Failed to fetch magiskboot release tag!"
log_ok "magiskboot release: ${LATESTMBOOT}"

# ── OTA mode setup ────────────────────────────
if [[ -z ${MODE} ]]; then
	:
elif [[ ${MODE} == "ota" ]]; then
	log_info "OTA mode selected — running preflight checks..."

	otacheck=$(getprop ota.other.vbmeta_digest)
	if [[ -z $otacheck ]]; then
		die "OTA mode is only usable after installing an update (before rebooting)!"
	fi

	if ! command -v su >/dev/null 2>&1; then
		die "OTA mode requires root (KernelSU / KernelSU-Next) with superuser access granted to shell!"
	fi

	curslot=$(getprop ro.boot.slot_suffix)
	case $curslot in
	_a | a) NEXTSLOT="b" ;;
	_b | b) NEXTSLOT="a" ;;
	*) die "Could not identify current boot slot!" ;;
	esac

	log_info "Current slot: ${curslot} → target slot: ${NEXTSLOT}"
	log_info "Dumping boot_${NEXTSLOT} to /sdcard/boot.img..."
	su -c "dd if=/dev/block/by-name/boot_${NEXTSLOT} of=/sdcard/boot.img" \
		|| die "Failed to dump boot_${NEXTSLOT}!"
	log_ok "Boot image dumped successfully."

	OTA=1
else
	die "Unknown mode '${MODE}'. Available option: ota"
fi

# ── Stage 1: workinit ─────────────────────────
workinit() {
	log_info "Setting up work directory..."
	mkdir -p ${WDIR}/work || die "Failed to create work directory!"
	cd ${WDIR}/work        || die "Failed to enter work directory!"

	log_info "Downloading ksud (${LATEST_KSUD}) from ${KSUD_REPO}..."
	if [[ ${NEED_UNZIP} == "1" ]]; then
		curl -sL "https://github.com/${KSUD_REPO}/releases/download/${LATEST_KSUD}/${KSUD}" \
			-o ${WDIR}/work/ksud.zip \
			|| die "Failed to download ksud!"
		unzip -j ksud.zip aarch64-linux-android/release/ksud \
			|| die "Failed to unzip ksud!"
		rm ksud.zip
	else
		curl -sL "https://github.com/${KSUD_REPO}/releases/download/${LATEST_KSUD}/${KSUD}" \
			-o ${WDIR}/work/ksud \
			|| die "Failed to download ksud!"
	fi
	log_ok "ksud downloaded."

	log_info "Downloading magiskboot (${LATESTMBOOT})..."
	curl -sL "https://github.com/cyberknight777/magisk_bins_ndk/releases/download/${LATESTMBOOT}/magiskboot" \
		-o ${WDIR}/work/magiskboot \
		|| die "Failed to download magiskboot!"
	log_ok "magiskboot downloaded."

	log_info "Downloading ${KSUM} (${LATEST_KO}) from ${KO_REPO}..."
	curl -sL "https://github.com/${KO_REPO}/releases/download/${LATEST_KO}/${KSUM}" \
		-o ${WDIR}/work/${KSUM} \
		|| die "Failed to download ${KSUM}!"
	log_ok "${KSUM} downloaded."

	chmod +x ksud magiskboot || die "Failed to set execute permissions!"
	log_ok "Work directory ready."
}

# ── Stage 2: patch ────────────────────────────
patch() {
	log_info "Patching boot image with ${KSUM} (KMI: android12-5.10)..."

	if [[ -z $OTA ]]; then
		./ksud boot-patch \
			-b /sdcard/boot.img \
			--kmi android12-5.10 \
			--magiskboot ${WDIR}/work/magiskboot \
			--module ${WDIR}/work/${KSUM} \
			-o /sdcard/Download/ \
			|| die "boot-patch failed!"
	else
		./ksud boot-patch \
			-b /sdcard/boot.img \
			--kmi android12-5.10 \
			--magiskboot ${WDIR}/work/magiskboot \
			--module ${WDIR}/work/${KSUM} \
			|| die "boot-patch failed!"
		mv kernelsu_*.img ksu.img || die "Failed to rename patched image!"
	fi

	log_ok "Boot image patched successfully."
}

# ── Stage 3: flash (OTA only) ─────────────────
flash() {
	if [[ -n $OTA ]]; then
		log_info "Checking if boot_${NEXTSLOT} is read-only..."
		rocheck=$(su -c "blockdev --getro /dev/block/by-name/boot_${NEXTSLOT}")
		if [[ $rocheck == "1" ]]; then
			log_info "Partition is read-only — setting writable..."
			su -c "blockdev --setrw /dev/block/by-name/boot_${NEXTSLOT}" \
				|| die "Failed to set boot_${NEXTSLOT} writable!"
			log_ok "Partition is now writable."
		fi

		log_info "Flashing patched image to boot_${NEXTSLOT}..."
		su -c "dd if=/data/local/tmp/work/ksu.img of=/dev/block/by-name/boot_${NEXTSLOT}" \
			|| die "Flash to boot_${NEXTSLOT} failed!"
		log_ok "Flashed to boot_${NEXTSLOT}."
	fi
}

# ── Stage 4: cleanup ──────────────────────────
cleanup() {
	log_info "Cleaning up work directory..."
	cd ${WDIR}           || die "Failed to return to working directory!"
	rm -rf ${WDIR}/work  || die "Failed to remove work directory!"
	log_ok "Cleanup done."
}

# ── Run ───────────────────────────────────────
workinit
patch
flash
cleanup

echo ""
if [[ -z $OTA ]]; then
	log_ok "Patched boot image is available at /sdcard/Download."
else
	log_ok "Patched image has been flashed to boot_${NEXTSLOT}. You may now reboot."
fi
