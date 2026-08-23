# Preparatory Homebrew formula for Tardigrade.
#
# The currently published Tardigrade release predates the native shipping
# cutover required by Bare-Systems/Tardigrade issue #466 and #634. Do not add
# release URLs here by hand. Generate this formula from Bare-Systems/Tardigrade
# once a qualifying native release exists.

class Tardigrade < Formula
  desc "Small Zig edge server for static file serving, reverse proxying, and TLS termination"
  homepage "https://github.com/Bare-Systems/Tardigrade"
  license "Apache-2.0"

  def install
    odie "No release-backed native Tardigrade Homebrew formula has been published yet"
  end
end
