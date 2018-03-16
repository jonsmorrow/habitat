studio_type="stage1"
studio_path="/bin:/tools/bin:/tools/usr/bin"
studio_env_command="/tools/usr/bin/env"
studio_enter_environment=
studio_enter_command="/tools/bin/bash --login +h"
studio_build_environment=
studio_build_command=
studio_run_environment=
studio_run_command=

: ${STAGE1_TOOLS_URL:=https://s3.us-east-2.amazonaws.com/mac-hab-stage1/tools.tar.xz}
: ${TAR_DIR:=/tmp}

finish_setup() {
  if [ -n "$HAB_ORIGIN_KEYS" ]; then
    for key in $(echo $HAB_ORIGIN_KEYS | tr ',' ' '); do
      local key_text
      # Import the secret origin key, required for signing packages
      info "Importing '$key' secret origin key"
      if key_text=$(hab origin key export --type secret $key); then
        printf -- "${key_text}" | _hab origin key import
      else
        echo "Error exporting $key key"
        # key_text will contain an error message
        echo "${key_text}"
        echo "Habitat was unable to export your secret signing key. Please"
        echo "verify that you have a signing key for $key present in either"
        echo "~/.hab/cache/keys (if running via sudo) or /hab/cache/keys"
        echo "(if running as root). You can test this by running:"
        echo ""
        echo "    hab origin key export --type secret $key"
        echo ""
        echo "This test will print your signing key to the console or error"
        echo "if it cannot find the key. To create a signing key, you can run: "
        echo ""
        echo "    hab origin key generate $key"
        echo ""
        echo "You'll also be prompted to create an origin signing key when "
        echo "you run 'hab setup'."
        echo ""
        exit 1
      fi
      # Attempt to import the public origin key, which can be used for local
      # package installations where the key may not yet be uploaded.
      if key_text=$(hab origin key export --type public $key 2> /dev/null); then
        info "Importing '$key' public origin key"
        printf -- "${key_text}" | _hab origin key import
      else
        info "Tried to import '$key' public origin key, but key was not found"
      fi
    done
  fi

  if [ -x "$HAB_STUDIO_ROOT/tools/bin/bash" ]; then
    return 0
  fi

  tar_file="$TAR_DIR/$(basename $STAGE1_TOOLS_URL)"

  # if [ ! -f $tar_file ]; then
  #   trap 'rm -f $tar_file; exit $?' INT TERM EXIT
  #   info "Downloading $STAGE1_TOOLS_URL"
  #   wget $STAGE1_TOOLS_URL -O $tar_file
  #   trap - INT TERM EXIT
  # fi

  info "Extracting $(basename $tar_file)"
  # xzcat $tar_file | tar xf - -C $HAB_STUDIO_ROOT

  #TODO: Put these in tools tar...
  mkdir -p $HAB_STUDIO_ROOT/tools/bin
  mkdir -p $HAB_STUDIO_ROOT/tools/usr/bin
  cp $(which bash) $HAB_STUDIO_ROOT/tools/bin
  cp $(which env) $HAB_STUDIO_ROOT/tools/usr/bin

  # Create symlinks from the minimal toolchain installed under `/tools` into
  # the root of the chroot environment. This is done to satisfy tools such as
  # `make(1)` which expect `/bin/sh` to exist.

  ln -sf $v /tools/bin/bash $HAB_STUDIO_ROOT/bin/bash
}

_hab() {
  env FS_ROOT=$HAB_STUDIO_ROOT HAB_CACHE_KEY_PATH= "@hab" "$@"
}
