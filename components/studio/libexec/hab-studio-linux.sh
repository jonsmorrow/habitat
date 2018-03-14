platform_home=/root

# **Internal** Creates a new Studio.
new_studio() {
  source_studio_type_config

  # Validate the type specified is valid and set a default if unset
  case "${STUDIO_TYPE:-unset}" in
    unset|default)
      # Set the default/unset type
      STUDIO_TYPE=default
      ;;
    busybox|stage1|baseimage|bare)
      # Confirmed valid types
      ;;
    *)
      # Everything else is invalid
      exit_with "Invalid Studio type: $STUDIO_TYPE" 2
      ;;
  esac

  # Properly canonicalize the root path of the Studio by following all symlinks.
  mkdir -p "$HAB_STUDIO_ROOT"
  HAB_STUDIO_ROOT="$(cd "$HAB_STUDIO_ROOT"; pwd -P)"

  info "Creating Studio at $HAB_STUDIO_ROOT ($STUDIO_TYPE)"

  # Mount filesystems

  mkdir -p $v "$HAB_STUDIO_ROOT"/dev
  mkdir -p $v "$HAB_STUDIO_ROOT"/proc
  mkdir -p $v "$HAB_STUDIO_ROOT"/sys
  mkdir -p $v "$HAB_STUDIO_ROOT"/run
  mkdir -p $v "$HAB_STUDIO_ROOT"/var/run

  # Unless `$NO_MOUNT` is set, mount filesystems such as `/dev`, `/proc`, and
  # company. If the mount already exists, skip it to be all idempotent and
  # nerdy like that
  if [ -z "${NO_MOUNT}" ]; then
    if ! mount | grep -q "on $HAB_STUDIO_ROOT/dev type"; then
      if [ -z "${KRANGSCHNAK+x}" ]; then
        mount $v --bind /dev "$HAB_STUDIO_ROOT"/dev
      else
        mount $v --rbind /dev "$HAB_STUDIO_ROOT"/dev
      fi
    fi

    if ! mount | grep -q "on $HAB_STUDIO_ROOT/dev/pts type"; then
      mount $v -t devpts devpts "$HAB_STUDIO_ROOT"/dev/pts -o gid=5,mode=620
    fi
    if ! mount | grep -q "on $HAB_STUDIO_ROOT/proc type"; then
      mount $v -t proc proc "$HAB_STUDIO_ROOT"/proc
    fi
    if ! mount | grep -q "on $HAB_STUDIO_ROOT/sys type"; then
      if [ -z "${KRANGSCHNAK+x}" ]; then
        mount $v -t sysfs sysfs "$HAB_STUDIO_ROOT"/sys
      else
        mount $v --rbind /sys "$HAB_STUDIO_ROOT"/sys
      fi
    fi
    if ! mount | grep -q "on $HAB_STUDIO_ROOT/run type"; then
      mount $v -t tmpfs tmpfs "$HAB_STUDIO_ROOT"/run
    fi
    if [ -e /var/run/docker.sock ]; then
      if ! mount | grep -q "on $HAB_STUDIO_ROOT/var/run/docker.sock type"; then
        touch "$HAB_STUDIO_ROOT"/var/run/docker.sock
        mount $v --bind /var/run/docker.sock "$HAB_STUDIO_ROOT"/var/run/docker.sock
      fi
    fi

    if [ -h "$HAB_STUDIO_ROOT/dev/shm" ]; then
      # Usage of readlink hear is cross platfrom since we don't use -f.
      mkdir -p $v $HAB_STUDIO_ROOT/$(readlink $HAB_STUDIO_ROOT/dev/shm)
    fi

    # Mount the `$ARTIFACT_PATH` under `/hab/cache/artifacts` in the Studio,
    # unless `$NO_ARTIFACT_PATH` are set
    if [ -z "${NO_ARTIFACT_PATH}" ]; then
      studio_artifact_path="${HAB_STUDIO_ROOT}${HAB_CACHE_ARTIFACT_PATH}"
      if ! mount | grep -q "on $studio_artifact_path type"; then
        mkdir -p $v "$ARTIFACT_PATH"
        mkdir -p $v "$studio_artifact_path"
        mount $v --bind "$ARTIFACT_PATH" "$studio_artifact_path"
      fi
    fi
  fi

  # Create root filesystem

  for top_level_dir in bin etc home lib mnt opt sbin var; do
    mkdir -p $v "$HAB_STUDIO_ROOT/$top_level_dir"
  done

  install -d $v -m 0750 "$HAB_STUDIO_ROOT/root"
  install -d $v -m 1777 "$HAB_STUDIO_ROOT/tmp" "$HAB_STUDIO_ROOT/var/tmp"

  for usr_dir in bin include lib libexec sbin; do
    mkdir -p $v "$HAB_STUDIO_ROOT/usr/$usr_dir"
  done

  for usr_share_dir in doc info locale man misc terminfo zoneinfo; do
    mkdir -p $v "$HAB_STUDIO_ROOT/usr/share/$usr_share_dir"
  done

  for usr_share_man_dir_num in 1 2 3 4 5 6 7 8; do
    mkdir -p $v "$HAB_STUDIO_ROOT/usr/share/man/man$usr_share_man_dir_num"
  done
  # If the system is 64-bit, a few symlinks will be required
  case $(uname -m) in
  x86_64)
    ln -sf $v lib "$HAB_STUDIO_ROOT/lib64"
    ln -sf $v lib "$HAB_STUDIO_ROOT/usr/lib64"
    ;;
  esac

  for var_dir in log mail spool opt cache local; do
    mkdir -p $v "$HAB_STUDIO_ROOT/var/$var_dir"
  done

  ln -sf $v /run/lock "$HAB_STUDIO_ROOT/var/lock"

  mkdir -p $v "$HAB_STUDIO_ROOT/var/lib/color"
  mkdir -p $v "$HAB_STUDIO_ROOT/var/lib/misc"
  mkdir -p $v "$HAB_STUDIO_ROOT/var/lib/locate"

  ln -sf $v /proc/self/mounts "$HAB_STUDIO_ROOT/etc/mtab"

  # Load the appropriate type strategy to complete the setup
  if [ -n "${HAB_STUDIO_BINARY:-}" ]; then
    studio_type_dir="$studio_binary_libexec_path"
  else
    studio_type_dir="$libexec_path"
  fi
  # shellcheck disable=1090
  . "$studio_type_dir/hab-studio-type-${STUDIO_TYPE}.sh"

  # If `/etc/passwd` is not present, create a minimal version to satisfy
  # some software when being built
  if [ ! -f "$HAB_STUDIO_ROOT/etc/passwd" ]; then
    if [ -n "$VERBOSE" ]; then
      echo "> Creating minimal /etc/passwd"
    fi
    cat > "$HAB_STUDIO_ROOT/etc/passwd" << "EOF"
root:x:0:0:root:/root:/bin/sh
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
  fi

  # If `/etc/group` is not present, create a minimal version to satisfy
  # some software when being built
  if [ ! -f "$HAB_STUDIO_ROOT/etc/group" ]; then
    if [ -n "$VERBOSE" ]; then
      echo "> Creating minimal /etc/group"
    fi
    cat > "$HAB_STUDIO_ROOT/etc/group" << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
nogroup:x:99:
users:x:999:
EOF
  fi

  # Copy minimal networking and DNS resolution configuration files into the
  # Studio filesystem so that commands such as `wget(1)` will work
  for f in /etc/hosts /etc/resolv.conf /etc/nsswitch.conf; do
    mkdir -p $v $(dirname $f)
    if [ $f = "/etc/nsswitch.conf" ] ; then
      touch "$HAB_STUDIO_ROOT$f"
      cat <<EOF > "$HAB_STUDIO_ROOT$f"
passwd:     files
group:      files
shadow:     files

hosts:      files dns
networks:   files

rpc:        files
services:   files
EOF
    else
      cp $v $f "$HAB_STUDIO_ROOT$f"
    fi
  done

  # Invoke the type's implementation
  finish_setup

  # Add a Studio configuration file at the root of the filesystem
  cat <<EOF > "$studio_config"
studio_type="$studio_type"
studio_path="$studio_path"
studio_env_command="${studio_env_command:?}"
studio_enter_environment="${studio_enter_environment?}"
studio_enter_command="${studio_enter_command:?}"
studio_build_environment="${studio_build_environment?}"
studio_build_command="${studio_build_command?}"
studio_run_environment="${studio_run_environment?}"
EOF

  # If `/etc/profile` is not present, create a minimal version with convenient
  # helper functions. "bare" studio doesn't need an /etc/profile
  if [ "$STUDIO_TYPE" != "bare" ]; then
    pfile="$HAB_STUDIO_ROOT/etc/profile"
    if [ ! -f "$pfile" ] || ! grep -q '^record() {$' "$pfile"; then
      if [ -n "$VERBOSE" ]; then
        echo "> Creating /etc/profile"
      fi

      if [ -n "${HAB_STUDIO_BINARY:-}" ]; then
        studio_profile_dir="$studio_binary_libexec_path"
      else
        studio_profile_dir="$libexec_path"
      fi
      cat "$studio_profile_dir/hab-studio-profile.sh" >> "$pfile"

    fi

    mkdir -p $v "$HAB_STUDIO_ROOT/src"
    # Mount the `$SRC_PATH` under `/src` in the Studio, unless either `$NO_MOUNT`
    # or `$NO_SRC_PATH` are set
    if [ -z "${NO_MOUNT}" ] && [ -z "${NO_SRC_PATH}" ]; then
      if ! mount | grep -q "on $HAB_STUDIO_ROOT/src type"; then
        mount $v --bind "$SRC_PATH" "$HAB_STUDIO_ROOT/src"
      fi
    fi
  fi
}

# **Internal** Unmount mount point if mounted and abort if an unmount is
# unsuccessful.
#
# ARGS: [umount_options] <mount_point>
umount_fs() {
  eval _mount_point=\$$# # getting the last arg is surprisingly hard

  if is_fs_mounted "${_mount_point:?}"; then
    # Filesystem is mounted, so attempt to unmount
    if umount "$@"; then
      # `umount` command was successful
      if ! is_fs_mounted "$_mount_point"; then
        # Filesystem is confirmed umounted, return success
        return 0
      else
        # Despite a successful umount, filesystem is still mounted
        #
        # TODO fn: there may a race condition here: if the `umount` is
        # performed asynchronously then it might still be reported as mounted
        # when the umounting is still queued up. We're erring on the side of
        # catching any possible races here to determine if there's a problem or
        # not. If this unduly impacts user experience then an alternate
        # approach is to wait/poll until the filesystem is unmounted (with a
        # deadline to abort).
        >&2 echo "After unmounting filesystem '$_mount_point', the mount \
persisted. Check that the filesystem is no longer in the mounted using \
\`mount(8)'and retry the last command."
        exit_with "Mount of $_mount_point persists" "$ERR_MOUNT_PERSISTS"
      fi
    else
      # `umount` command reported a failure
      >&2 echo "An error occurred when unmounting filesystem '$_mount_point'"
      exit_with "Unmount of $_mount_point failed" "$ERR_UMOUNT_FAILED"
    fi
  else
    # Filesystem is not mounted, return success
    return 0
  fi
}

# **Internal** Determines if a given filesystem is currently mounted. Returns 0
# if true and non-zero otherwise.
is_fs_mounted() {
  _mount_point="${1:?}"

  mount | grep -q "on $_mount_point type"
}

# **Internal** Unmounts file system mounts if mounted. The order of file system
# unmounting is important as it is the opposite of the initial mount order.
#
# Any failures to successfully unmount a filesystem that is mounted will result
# in the program aborting with an error message. As this function's behavior is
# convergent on success and fast fail on failures, this can be safely run
# multiple times across differnt program invocations.
unmount_filesystems() {
  umount_fs $v -l "$HAB_STUDIO_ROOT/src"

  studio_artifact_path="${HAB_STUDIO_ROOT}${HAB_CACHE_ARTIFACT_PATH}"
  umount_fs $v -l "$studio_artifact_path"

  umount_fs $v "$HAB_STUDIO_ROOT/run"

  if [ -z "${KRANGSCHNAK+x}" ]; then
    umount_fs $v "$HAB_STUDIO_ROOT/sys"
  else
    umount_fs $v -l "$HAB_STUDIO_ROOT/sys"
  fi

  umount_fs $v "$HAB_STUDIO_ROOT/proc"

  umount_fs $v "$HAB_STUDIO_ROOT/dev/pts"

  umount_fs $v -l "$HAB_STUDIO_ROOT/dev"

  umount_fs $v -l "$HAB_STUDIO_ROOT/var/run/docker.sock"
}
