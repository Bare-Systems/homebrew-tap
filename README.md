# Bare Systems Homebrew Tap

Homebrew formulas for Bare Systems projects.

## Tardigrade

The tap currently publishes the Linux Homebrew formula for Tardigrade `0.5.0`,
using the release archives and SHA-256 values from
[`tardigrade-checksums.txt`](https://github.com/Bare-Systems/Tardigrade/releases/download/v0.5.0/tardigrade-checksums.txt).

```bash
brew tap Bare-Systems/tap
brew install tardigrade

tardi version
```

The canonical executable is `tardi`. The formula also installs the release
archive's `tardigrade` compatibility executable while that alias remains part of
Tardigrade packaging.

macOS formula branches are intentionally absent until Tardigrade publishes real
`tardigrade-darwin-x86_64.tar.gz` and `tardigrade-darwin-arm64.tar.gz` release
archives with manifest checksums. The formula does not depend on `openssl@3`;
native release artifacts are expected to satisfy Tardigrade's runtime TLS
contract without a Homebrew OpenSSL runtime dependency.

## Formula Ownership

This tap is the public Homebrew installation surface for released Tardigrade
artifacts. Formula updates are generated from one Tardigrade release at a time:

1. Tardigrade publishes release archives and `tardigrade-checksums.txt`.
2. `scripts/update-tardigrade-formula.rb` reads that release and rewrites
   `Formula/tardigrade.rb` deterministically.
3. The tap CI installs the formula and runs the Homebrew test on Linux.
4. The rendered formula is reviewed and merged in this repository.

Do not hand-edit version, URL, or checksum values independently from the release
manifest.

## Updating Tardigrade

Render the latest Tardigrade formula:

```bash
scripts/update-tardigrade-formula.rb
```

Render a specific release:

```bash
scripts/update-tardigrade-formula.rb v0.5.0
```

Then run:

```bash
ruby -c Formula/tardigrade.rb
brew tap Bare-Systems/tap "$PWD"
brew audit --formula Bare-Systems/tap/tardigrade
brew test Bare-Systems/tap/tardigrade
```

`brew test` requires a Linux host for the currently published formula because no
macOS release archives are available yet.
