#!/bin/sh
# Test matrix: install rihla as a non-root user in a fresh container and run test/assert.sh.
#
#   test/run.sh centos7                 one distro
#   test/run.sh centos7 rocky8 ubuntu24  several, one container at a time
#   test/run.sh all                     every distro below
#   test/run.sh --offline centos7       install from a bundle with the network off
#   test/run.sh local                   no docker: run the assertions here with a throwaway HOME
#   test/run.sh tmux-versions           the tmux bar (test/bar.sh) on each distro's own tmux,
#                                       1.8 to 3.4, without installing rihla
#   RIHLA_TEST_PROXY=http://172.17.0.1:3128 test/run.sh centos7   download through a proxy
#   RIHLA_TEST_TMPFS=2g test/run.sh centos7   a smaller home (it is RAM; default 3g)
#
# Each container: the repo is mounted read-only, the test user's home is a tmpfs (installs
# land in RAM, nothing is left on disk), downloads are cached in $RIHLA_TEST_CACHE between
# runs, and the container is removed afterwards. Needs docker (no root inside the test).
#
# Baseline: what a minimal machine of each distro has, plus curl/CA certificates where the
# image lacks them. Variants marked "+pkgs" add the distro's own git and tmux as an
# administrator would, to exercise the "old system tmux / old git" paths. zsh is added on
# centos7-pkgs (5.0.2, the oldest the shell layer supports) and rocky9 (5.8, with xz so
# that fish and ble.sh can be unpacked); the other rows have no zsh, so the shell layer
# is tested there with bash only.

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
PREFIX=${RIHLA_TEST_PREFIX:-rihla-test}
CACHE=${RIHLA_TEST_CACHE:-${TMPDIR:-/tmp}/rihla-test-cache}
OFFLINE=
UID_T=4242

# Languages whose language server the LSP end-to-end check installs and proves, per
# distro (RIHLA_TEST_LSP overrides). lua_ls is a prebuilt binary that runs on glibc 2.17;
# python needs python3 with venv (basedpyright on 3.10+, pylsp below).
lsp_langs() {
	case $1 in
	rocky9 | fedora-py) echo lua,python ;;
	*) echo lua ;;
	esac
}

# name | image | root setup command (run before the test, as root)
distro_row() {
	case $1 in
	centos7) echo "centos:7|true" ;;
	centos7-pkgs) echo "centos:7|sed -i -e 's/^mirrorlist/#mirrorlist/' -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|' /etc/yum.repos.d/CentOS-Base.repo && yum -q -y install git tmux zsh >/dev/null" ;;
	rocky8) echo "rockylinux:8|dnf -q -y install git tmux tar >/dev/null" ;;
	rocky9) echo "quay.io/rockylinux/rockylinux:9|dnf -q -y install tar zsh xz >/dev/null" ;;
	ubuntu22) echo "ubuntu:22.04|apt-get -qq update && apt-get -qq install -y --no-install-recommends curl ca-certificates git tmux >/dev/null" ;;
	ubuntu24) echo "ubuntu:24.04|apt-get -qq update && apt-get -qq install -y --no-install-recommends curl ca-certificates >/dev/null" ;;
	debian12) echo "debian:12|apt-get -qq update && apt-get -qq install -y --no-install-recommends wget ca-certificates tmux >/dev/null" ;;
	# fedora has xz: ble.sh is installed; with ps (procps-ng) here it loads and is typed
	# into, while fedora-py (no ps, as the bare image) checks that it is skipped and named.
	fedora) echo "fedora:latest|dnf -q -y install tar procps-ng >/dev/null" ;;
	fedora-py) echo "fedora:latest|dnf -q -y install tar python3 >/dev/null" ;;
	arch) echo "archlinux:latest|pacman -Sy --noconfirm --needed git tmux >/dev/null" ;;
	*) return 1 ;;
	esac
}
# The tmux bar on the tmux each distro ships: name | image | root setup.
tmux_row() {
	case $1 in
	tmux-1.8) echo "centos:7|sed -i -e 's/^mirrorlist/#mirrorlist/' -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|' /etc/yum.repos.d/CentOS-Base.repo && yum -q -y install git tmux >/dev/null" ;;
	tmux-2.7) echo "rockylinux:8|dnf -q -y install git tmux >/dev/null" ;;
	tmux-3.0) echo "ubuntu:20.04|apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get -qq install -y --no-install-recommends git tmux >/dev/null" ;;
	tmux-3.1) echo "debian:11|apt-get -qq update && apt-get -qq install -y --no-install-recommends tmux >/dev/null && { apt-get -qq install -y --no-install-recommends git >/dev/null || true; }" ;;
	tmux-3.2) echo "ubuntu:22.04|apt-get -qq update && apt-get -qq install -y --no-install-recommends git tmux >/dev/null" ;;
	tmux-3.3) echo "debian:12|apt-get -qq update && apt-get -qq install -y --no-install-recommends git tmux >/dev/null" ;;
	tmux-3.4) echo "ubuntu:24.04|apt-get -qq update && apt-get -qq install -y --no-install-recommends git tmux >/dev/null" ;;
	*) return 1 ;;
	esac
}
TMUX_ALL="tmux-1.8 tmux-2.7 tmux-3.0 tmux-3.1 tmux-3.2 tmux-3.3 tmux-3.4"

run_tmux_row() {
	name=$1
	row=$(tmux_row "$name") || return 2
	image=${row%%|*}
	setup=${row#*|}
	c=$PREFIX-$name
	log=$LOGDIR/$name.log
	echo "== $name ($image)"
	docker rm -f "$c" >/dev/null 2>&1
	docker run -d --name "$c" --tmpfs /tmp:exec,size=512m -v "$SRC:/src:ro" "$image" sleep 1800 >/dev/null || return 1
	docker exec "$c" sh -c "$setup" >"$log" 2>&1 || echo "   (root setup failed, see $log)"
	docker exec -e LANG=C.UTF-8 -e TERM=xterm-256color "$c" sh /src/test/bar.sh tmux >>"$log" 2>&1
	rc=$?
	docker rm -f "$c" >/dev/null 2>&1
	grep '^RESULT\|^== bar' "$log" | sed "s/^/   /"
	if [ $rc -eq 0 ]; then echo "$name PASS" >>"$SUMMARY"; else echo "$name FAIL" >>"$SUMMARY"; fi
	return $rc
}

ALL="centos7 centos7-pkgs rocky8 rocky9 ubuntu22 ubuntu24 debian12 fedora fedora-py arch"

# A clean copy of the tree: tracked and new files, nothing git-ignored or excluded.
export_tree() {
	dest=$1
	rm -rf "$dest"
	mkdir -p "$dest"
	if [ -d "$ROOT/.git" ] && command -v git >/dev/null 2>&1; then
		(cd "$ROOT" && git ls-files -co --exclude-standard -z | xargs -0 tar -cf -) | (cd "$dest" && tar -xf -)
	else
		(cd "$ROOT" && tar -cf - --exclude=.git .) | (cd "$dest" && tar -xf -)
	fi
}

run_local() {
	h=$(mktemp -d "${TMPDIR:-/tmp}/rihla-local-home.XXXXXX")
	s=$(mktemp -d "${TMPDIR:-/tmp}/rihla-local-src.XXXXXX")
	export_tree "$s"
	echo "== local run, HOME=$h"
	# A clean environment: the tests start interactive shells, and anything exported here
	# (HISTFILE, STARSHIP_*, ZDOTDIR, XDG_*, TMUX) would point them at the real home.
	# shellcheck disable=SC2086
	env -i PATH="$PATH" HOME="$h" USER="${USER:-$(id -un)}" LOGNAME="${LOGNAME:-$(id -un)}" \
		LANG="${LANG:-C.UTF-8}" TERM=xterm-256color SHELL=/bin/sh TMPDIR="${TMPDIR:-/tmp}" \
		RIHLA_CACHE="$CACHE" ${RIHLA_TEST_LSP+RIHLA_TEST_LSP="$RIHLA_TEST_LSP"} \
		${https_proxy:+https_proxy="$https_proxy"} ${http_proxy:+http_proxy="$http_proxy"} ${no_proxy:+no_proxy="$no_proxy"} \
		sh "$s/test/assert.sh" ${OFFLINE:+--offline "$OFFLINE"} >"$LOGDIR/local.log" 2>&1
	rc=$?
	cat "$LOGDIR/local.log"
	rm -rf "$h" "$s"
	if [ $rc -eq 0 ]; then echo "local PASS" >>"$SUMMARY"; else echo "local FAIL" >>"$SUMMARY"; fi
	return $rc
}

run_one() {
	name=$1
	row=$(distro_row "$name") || {
		echo "unknown distro: $name (known: $ALL)" >&2
		return 2
	}
	image=${row%%|*}
	setup=${row#*|}
	c=$PREFIX-$name
	log=$LOGDIR/$name.log
	echo "== $name ($image)"
	docker rm -f "$c" >/dev/null 2>&1
	if [ -n "$OFFLINE" ]; then
		# No network at all, no download cache: everything must come from the bundle.
		# The root setup is skipped too (it would need the network); tar and gzip suffice.
		setup=true
		set -- --network none -v "$OFFLINE:/bundle.tar.gz:ro"
		envs="-e RIHLA_TEST_OFFLINE=1"
	else
		set -- -v "$CACHE:/cache"
		envs="-e RIHLA_CACHE=/cache"
	fi
	# RIHLA_TEST_PROXY=http://host:port: the test user downloads through that proxy
	# (passed as the uppercase variables, which rihla mirrors to the lowercase ones).
	if [ -n "${RIHLA_TEST_PROXY:-}" ]; then
		envs="$envs -e HTTPS_PROXY=$RIHLA_TEST_PROXY -e HTTP_PROXY=$RIHLA_TEST_PROXY"
	fi
	docker run -d --name "$c" \
		--tmpfs /home/tester:exec,uid=$UID_T,gid=$UID_T,size=${RIHLA_TEST_TMPFS:-3g} \
		--tmpfs /tmp:exec,size=1g \
		-v "$SRC:/src:ro" "$@" \
		"$image" sleep 7200 >/dev/null || return 1
	docker exec "$c" sh -c "echo 'tester:x:$UID_T:$UID_T::/home/tester:/bin/bash' >>/etc/passwd; echo 'tester:x:$UID_T:' >>/etc/group; $setup" >"$log" 2>&1 ||
		echo "   (root setup failed, see $log)"
	# Tools the test itself needs (not rihla): find for the home snapshot, script (a pty
	# for the tmux client in test/nav.sh).
	if [ -z "$OFFLINE" ]; then
		docker exec "$c" sh -c 'command -v find >/dev/null || { command -v dnf >/dev/null && dnf -q -y install findutils >/dev/null; }
			command -v script >/dev/null || { command -v dnf >/dev/null && dnf -q -y install /usr/bin/script >/dev/null; }' >>"$log" 2>&1
	fi
	if [ -n "$OFFLINE" ]; then
		docker exec "$c" sh -c 'echo "== network: $(curl -sS -m 5 -o /dev/null https://github.com >/dev/null 2>&1 && echo UP || echo none)"' >>"$log" 2>&1
	fi
	# shellcheck disable=SC2086
	docker exec -u "$UID_T:$UID_T" -e HOME=/home/tester -e USER=tester -e SHELL=/bin/bash -e TERM=xterm-256color \
		-e LANG=C.UTF-8 -e RIHLA_TEST_LSP="${RIHLA_TEST_LSP-$(lsp_langs "$name")}" $envs -w /home/tester "$c" \
		sh /src/test/assert.sh ${OFFLINE:+--offline /bundle.tar.gz} >>"$log" 2>&1
	rc=$?
	docker rm -f "$c" >/dev/null 2>&1
	grep '^RESULT\|^== system\|^== network\|^== tool\|^== plugins' "$log" | sed "s/^/   /"
	if [ $rc -eq 0 ]; then
		echo "$name PASS" >>"$SUMMARY"
	else
		echo "$name FAIL" >>"$SUMMARY"
	fi
	return $rc
}

while [ $# -gt 0 ]; do
	case $1 in
	--offline)
		OFFLINE=$2
		shift
		;;
	*) break ;;
	esac
	shift
done
[ $# -gt 0 ] || {
	sed -n '2,16p' "$0"
	echo "distros: $ALL"
	exit 2
}
[ "$1" = all ] && set -- $ALL
[ "$1" = tmux-versions ] && set -- $TMUX_ALL
[ -z "$OFFLINE" ] || OFFLINE=$(cd "$(dirname "$OFFLINE")" && pwd -P)/$(basename "$OFFLINE")

LOGDIR=${RIHLA_TEST_LOGS:-${TMPDIR:-/tmp}/rihla-test-logs}
mkdir -p "$LOGDIR" "$CACHE"
SUMMARY=$LOGDIR/summary
: >"$SUMMARY"
if [ "$1" = local ]; then
	run_local
	exit $?
fi
SRC=$(mktemp -d "${TMPDIR:-/tmp}/rihla-src.XXXXXX")
export_tree "$SRC"
chmod -R a+rX "$SRC"
chmod -R a+rwX "$CACHE"
status=0
for d in "$@"; do
	case $d in
	tmux-*) run_tmux_row "$d" || status=1 ;;
	*) run_one "$d" || status=1 ;;
	esac
done
rm -rf "$SRC"
echo
echo "== summary (logs in $LOGDIR)"
cat "$SUMMARY"
exit $status
