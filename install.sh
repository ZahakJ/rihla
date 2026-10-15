#!/bin/sh
# rihla bootstrap.
#
#   curl -fsSL https://raw.githubusercontent.com/ZahakJ/rihla/main/install.sh | sh
#   wget -qO- https://raw.githubusercontent.com/ZahakJ/rihla/main/install.sh | sh
#   sh install.sh                      # from a checkout: installs that checkout
#   sh install.sh --offline BUNDLE     # from a bundle made by 'rihla bundle', no network
#
# Puts rihla in $RIHLA_HOME (default ~/.local/share/rihla) and runs 'rihla install'.
# Never uses sudo. Any other option is passed to 'rihla install' (see 'rihla help').
#
# POSIX sh. Everything is inside main() so a truncated download runs nothing.

main() {
	set -u
	REPO_URL=${RIHLA_REPO:-https://github.com/ZahakJ/rihla}
	REF=${RIHLA_REF:-main}
	DEST=${RIHLA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/rihla}
	OFFLINE=
	PASS=

	while [ $# -gt 0 ]; do
		case $1 in
		--offline)
			OFFLINE=${2:?--offline needs a bundle file}
			shift
			;;
		--home)
			DEST=${2:?--home needs a directory}
			shift
			;;
		--ref)
			REF=${2:?--ref needs a branch or tag}
			shift
			;;
		*) PASS="$PASS $(quote "$1")" ;;
		esac
		shift
	done

	# Check the basics before touching anything (bin/rihla checks again, in more detail).
	missing=
	for c in tar gzip mkdir sed awk grep cksum; do
		command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
	done
	if [ -z "$OFFLINE" ] && ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
		missing="$missing curl-or-wget"
	fi
	if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1 && ! command -v openssl >/dev/null 2>&1; then
		missing="$missing sha256sum-or-shasum-or-openssl"
	fi
	[ -z "$missing" ] || fail "missing required commands:$missing (nothing was changed)"

	# Where does this script live? A checkout next to it is installed as is.
	SRC=
	case $0 in
	*/install.sh | install.sh)
		d=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P) || d=
		[ -n "$d" ] && [ -f "$d/bin/rihla" ] && [ -f "$d/lib/manifest" ] && SRC=$d
		;;
	esac

	TMP=$(mktemp -d "${TMPDIR:-/tmp}/rihla-install.XXXXXX") || fail "mktemp failed"
	trap 'rm -rf "$TMP"' EXIT
	trap 'exit 130' INT TERM

	if [ -n "$OFFLINE" ]; then
		[ -f "$OFFLINE" ] || fail "no such bundle: $OFFLINE"
		log "unpacking $OFFLINE"
		gzip -dc "$OFFLINE" | (cd "$TMP" && tar -xf -) || fail "cannot unpack $OFFLINE"
		[ -f "$TMP/rihla-bundle/rihla/bin/rihla" ] || fail "$OFFLINE is not a rihla bundle"
		SRC=$TMP/rihla-bundle/rihla
		PASS="$PASS --offline-dir $(quote "$TMP/rihla-bundle")"
	fi

	if [ -n "$DEST" ] && [ -e "$DEST" ] && [ ! -f "$DEST/bin/rihla" ]; then
		fail "$DEST exists and is not a rihla install; move it away or set RIHLA_HOME"
	fi

	# Directories created here are recorded so 'rihla uninstall' can remove them again.
	CREATED=
	d=$(dirname "$DEST")
	while [ ! -d "$d" ]; do
		CREATED="$d
$CREATED"
		d=$(dirname "$d")
	done
	HOME_CREATED=
	[ -d "$DEST" ] || HOME_CREATED=1

	CHANGED=
	if [ -n "$SRC" ]; then
		if [ "$SRC" = "$(cd "$DEST" 2>/dev/null && pwd -P)" ]; then
			log "installing from $SRC in place"
		else
			copy_tree "$SRC" "$DEST"
		fi
	else
		fetch_repo
	fi

	# A fresh RIHLA_HOME (or one an earlier install.sh made) belongs to rihla.
	if [ -n "$HOME_CREATED" ] || [ -f "$DEST/.rihla-source" ]; then
		RIHLA_HOME_CREATED=1
	else
		RIHLA_HOME_CREATED=
	fi
	export RIHLA_HOME_CREATED
	RIHLA_CREATED_DIRS=$CREATED
	export RIHLA_CREATED_DIRS
	RIHLA_HOME_CHANGED=$CHANGED
	export RIHLA_HOME_CHANGED

	eval "set -- $PASS"
	sh "$DEST/bin/rihla" install "$@"
}

log() { printf '==> %s\n' "$*"; }
fail() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}
quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

download() { # download URL OUT
	if command -v curl >/dev/null 2>&1; then
		curl -fL -sS --retry 3 --connect-timeout 20 -o "$2" "$1"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -T 20 -t 3 -O "$2" "$1"
	else
		fail "missing required command: curl or wget"
	fi
}

# The source tree as a tar stream on stdout. From a git checkout only what git would ship
# (tracked and new files, nothing ignored or listed in .git/info/exclude), so a working
# copy's private notes and build leftovers never reach RIHLA_HOME or a bundle made from it.
tree_tar() {
	if [ -e "$1/.git" ] && command -v git >/dev/null 2>&1 &&
		(cd "$1" && git -c safe.directory='*' rev-parse --is-inside-work-tree >/dev/null 2>&1); then
		# ls-files also lists tracked files deleted in the working tree; tar must not see those.
		(cd "$1" && git -c safe.directory='*' ls-files -co --exclude-standard | while IFS= read -r f; do
			[ -e "$f" ] || [ -L "$f" ] && printf '%s\n' "$f"
		done | LC_ALL=C sort | tar -cf - -T - 2>/dev/null)
	else
		# No usable git: honour the plain patterns of .gitignore and .git/info/exclude.
		(cd "$1" && cat .gitignore .git/info/exclude 2>/dev/null |
			sed -n -e '/^[[:space:]]*#/d' -e '/^!/d' -e 's#^/##' -e 's#/$##' -e '/./p' >"$TMP/excl"
		printf '%s\n' .git .rihla-source >>"$TMP/excl"
		tar -cf - -X "$TMP/excl" . 2>/dev/null)
	fi
}

# Fingerprint of a source tree: the tar stream of it (names, sizes, mtimes, contents).
tree_sum() { tree_tar "$1" | cksum | awk '{print $1 "-" $2}'; }

copy_tree() { # copy_tree SRC DEST, skipped when SRC has not changed since the last copy
	sum=$(tree_sum "$1")
	if [ -f "$2/.rihla-source" ] && [ "$(cat "$2/.rihla-source")" = "$sum" ]; then
		log "rihla files in $2 are current"
		return 0
	fi
	log "copying $1 -> $2"
	new=$2.new-$$
	rm -rf "$new"
	mkdir -p "$new" || fail "cannot create $new"
	tree_tar "$1" | (cd "$new" && tar -xf -) || fail "copy failed"
	printf '%s\n' "$sum" >"$new/.rihla-source"
	swap_in "$new" "$2"
	CHANGED=1
}

swap_in() { # swap_in NEW DEST
	if [ -d "$2" ]; then
		mv "$2" "$2.old-$$" || fail "cannot move $2 aside"
		mv "$1" "$2" || {
			mv "$2.old-$$" "$2"
			fail "cannot replace $2"
		}
		rm -rf "$2.old-$$"
	else
		mkdir -p "$(dirname "$2")" && mv "$1" "$2" || fail "cannot create $2"
	fi
}

fetch_repo() {
	if [ -d "$DEST/.git" ] && command -v git >/dev/null 2>&1; then
		log "updating $DEST with git"
		before=$(cd "$DEST" && git rev-parse HEAD 2>/dev/null)
		(cd "$DEST" && git checkout -q -- nvim/lazy-lock.json 2>/dev/null
		git fetch -q --depth 1 origin "$REF" && git reset -q --hard FETCH_HEAD) ||
			fail "git update of $DEST failed"
		[ "$before" = "$(cd "$DEST" && git rev-parse HEAD)" ] || CHANGED=1
		return 0
	fi
	if command -v git >/dev/null 2>&1 && [ ! -e "$DEST" ]; then
		log "cloning $REPO_URL ($REF)"
		if git clone -q --depth 1 -b "$REF" "$REPO_URL.git" "$TMP/src" 2>"$TMP/git.err"; then
			printf 'git\n' >"$TMP/src/.rihla-source"
			swap_in "$TMP/src" "$DEST"
			CHANGED=1
			return 0
		fi
		log "git clone failed ($(head -n 1 "$TMP/git.err")); falling back to a tarball"
	fi
	log "downloading $REPO_URL ($REF) as a tarball"
	download "$REPO_URL/archive/$REF.tar.gz" "$TMP/src.tar.gz" || fail "download failed (proxy? set https_proxy)"
	mkdir "$TMP/x" && gzip -dc "$TMP/src.tar.gz" | (cd "$TMP/x" && tar -xf -) || fail "cannot unpack the download"
	src=$TMP/x/$(ls "$TMP/x" | head -n 1)
	[ -f "$src/bin/rihla" ] || fail "the download does not contain bin/rihla"
	copy_tree "$src" "$DEST"
}

main "$@"
