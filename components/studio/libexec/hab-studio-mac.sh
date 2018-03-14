platform_home=/var/root

# **Internal** Creates a new Studio.
new_studio() {
  source_studio_type_config
  
  # Validate the type specified is valid and set a default if unset
  case "${STUDIO_TYPE:-unset}" in
    unset|stage1)
      # Set the stage1/unset type
      STUDIO_TYPE=stage1
      ;;
    *)
      # Everything else is invalid
      exit_with "Invalid Studio type: $STUDIO_TYPE" 2
      ;;
  esac

  # Properly canonicalize the root path of the Studio by following all symlinks.
  mkdir -p $HAB_STUDIO_ROOT
  HAB_STUDIO_ROOT="$(cd $HAB_STUDIO_ROOT; pwd -P)"

  info "Creating Studio at $HAB_STUDIO_ROOT ($STUDIO_TYPE)"

  # Set the verbose flag (i.e. `-v`) for any coreutils-like commands if verbose
  # mode was requested
  if [ -n "$VERBOSE" ]; then
    local v="-v"
  else
    local v=
  fi

  # Create root filesystem

  mkdir -p $v $HAB_STUDIO_ROOT/bin
  mkdir -p $v $HAB_STUDIO_ROOT/usr
  mkdir -p $v $HAB_STUDIO_ROOT/dev

  # Load the appropriate type strategy to complete the setup
  . $libexec_path/hab-studio-mac-type-${STUDIO_TYPE}.sh

  # Invoke the type's implementation
  finish_setup

  # Add a Studio configuration file at the root of the filesystem
  cat <<EOF > "$studio_config"
studio_type="$studio_type"
studio_path="$studio_path"
studio_env_command="$studio_env_command"
studio_enter_environment="$studio_enter_environment"
studio_enter_command="$studio_enter_command"
studio_build_environment="$studio_build_environment"
studio_build_command="$studio_build_command"
studio_run_environment="$studio_run_environment"
EOF

  # exit_with "Mac not implemented yet" 100
}

# **Internal** Unmount mount point if mounted
# Don't abort script on umount failure
# ARGS: [umount_options] <mount_point>
try_umount() {
  eval _mount_point=\$$# # getting the last arg is surprisingly hard
  if mount | grep -q "on $_mount_point (osxfuse, synchronous)"; then
    try umount $*
  fi
}

# **Internal** Unmounts file system mounts if mounted. The order of file system
# unmounting is important as it is the opposite of the initial mount order
unmount_filesystems() {
  # Set the verbose flag (i.e. `-v`) for any coreutils-like commands if verbose
  # mode was requested
  if [ -n "$VERBOSE" ]; then
    local v="-v"
  else
    local v=
  fi

  # Unmount file systems that were previously set up in new_studio, but only if
  # they are currently mounted. You know, so you can run this all day long,
  # like, for fun and stuff.


}

# **Internal** Adds platform specific binaries to the path.
set_path_for_platform() {
  # Mac specific setup
  if ! command -v bindfs > /dev/null; then
    exit_with "'bindfs' command must be on PATH" 99
  fi

  # Put bindfs, mount, umount into libexec_path
  # TODO: Revisit what of this can be shipped in the mac package.
  mkdir -p $libexec_path/sys_bin
  ln -fsv $(which bindfs) $libexec_path/sys_bin/bindfs
  ln -fsv $(which mount) $libexec_path/sys_bin/mount
  ln -fsv $(which umount) $libexec_path/sys_bin/umount

  # Put additional commands in path.
  # TODO: These should be provided internally to the package.
  ln -fsv $(which awk) $libexec_path/sys_bin/awk
  ln -fsv $(which basename) $libexec_path/sys_bin/basename
  ln -fsv $(which cat) $libexec_path/sys_bin/cat
  ln -fsv $(which chroot) $libexec_path/sys_bin/chroot
  ln -fsv $(which env) $libexec_path/sys_bin/env
  ln -fsv $(which id) $libexec_path/sys_bin/id
  ln -fsv $(which ln) $libexec_path/sys_bin/ln
  ln -fsv $(which mkdir) $libexec_path/sys_bin/mkdir
  ln -fsv $(which readlink) $libexec_path/sys_bin/readlink
  ln -fsv $(which rm) $libexec_path/sys_bin/rm
  ln -fsv $(which sed) $libexec_path/sys_bin/sed
  ln -fsv $(which tar) $libexec_path/sys_bin/tar
  ln -fsv $(which wget) $libexec_path/sys_bin/wget
  ln -fsv $(which xzcat) $libexec_path/sys_bin/xzcat
  path_for_platform=$libexec_path/sys_bin
}
