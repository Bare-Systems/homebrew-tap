# Bare Systems Homebrew Tap

This repository is the public Homebrew publication surface for Bare Systems
formulae.

## Tardigrade

Tardigrade Homebrew installation is not publicly supported yet. The latest
published Tardigrade release does not satisfy the native release-backed
Homebrew contract from `Bare-Systems/Tardigrade` issue #466, so this tap must
not advertise the old release as installable.

Once a qualifying native release has been published and this tap's CI passes
against the generated formula, the public install path will be:

```bash
brew tap Bare-Systems/tap
brew install tardigrade
```

The installed canonical executable is `tardi`. The `tardigrade` command remains
a compatibility alias only while current Tardigrade packaging promises it.

Tardigrade does not have a Homebrew `openssl@3` runtime dependency. Native
release artifacts are expected to satisfy Tardigrade's TLS contract without
linking the installed `tardi` binary against Homebrew OpenSSL.

## Formula Ownership

`Bare-Systems/Tardigrade` owns formula generation. This tap receives and reviews
the generated publication artifact; it is not a second implementation of release
asset discovery, checksum selection, or formula rendering.

The intended release-to-tap flow is:

```text
Bare-Systems/Tardigrade release
    -> Tardigrade/scripts/update-homebrew-formula.sh
    -> Tardigrade/packaging/homebrew/tardigrade.rb
    -> Bare-Systems/homebrew-tap/Formula/tardigrade.rb
    -> tap CI
    -> public Homebrew installation
```

For a future release, run the canonical updater from a checked-out Tardigrade
repository:

```bash
./scripts/update-homebrew-formula.sh \
  --tag vX.Y.Z \
  --tap-dir ../homebrew-tap
```

Then review the tap diff and run tap validation before opening the tap PR:

```bash
scripts/validate-tardigrade-formula.sh
```

Do not hand-edit formula versions, URLs, checksums, or platform branches in this
repository. They must come from one published Tardigrade release and pass the
native inventory checks performed by Tardigrade's updater.

## Current Follow-Up

The merged Tardigrade updater currently copies
`packaging/homebrew/tap-README.md` when `--tap-dir` is used. This tap README is
intentionally stable and tap-owned; the Tardigrade updater should be changed to
sync only the generated formula, or otherwise avoid replacing this public README
with release-specific preparatory text.
