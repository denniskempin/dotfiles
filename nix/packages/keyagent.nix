# Darwin-only. The offline suite (`cargo test` in keyagent/) also runs on Linux;
# this derivation is what launchd starts, and it needs the macOS SDK.
{
  lib,
  rustPlatform,
  stdenv,
}:
rustPlatform.buildRustPackage {
  pname = "keyagent";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ../../keyagent/Cargo.toml
      ../../keyagent/Cargo.lock
      ../../keyagent/src
      ../../keyagent/tests
      ../../keyagent/Info.plist
      ../../configs/keyagent
    ];
  };

  # Cargo.toml is not at the root, so the grammar in configs/keyagent stays
  # next to it and the snapshot test can see both.
  cargoRoot = "keyagent";
  buildAndTestSubdir = "keyagent";
  cargoLock.lockFile = ../../keyagent/Cargo.lock;

  postInstall = ''
    app="$out/Applications/Keyagent.app/Contents"
    mkdir -p "$app/MacOS"
    mv "$out/bin/keyagent" "$app/MacOS/keyagent"
    rmdir "$out/bin"
    cp ${../../keyagent/Info.plist} "$app/Info.plist"
  ''
  + lib.optionalString stdenv.isDarwin ''
    /usr/bin/codesign --force --sign - "$out/Applications/Keyagent.app"
  '';

  meta = {
    description = "Layer keybindings for AeroSpace and the front app";
    platforms = lib.platforms.darwin;
  };
}
