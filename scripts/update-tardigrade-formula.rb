#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open-uri"

REPO = "Bare-Systems/Tardigrade"
FORMULA_PATH = File.expand_path("../Formula/tardigrade.rb", __dir__)
GITHUB_API = "https://api.github.com/repos/#{REPO}"
GITHUB_HEADERS = {
  "Accept" => "application/vnd.github+json",
  "GitHub-Api-Version" => "2022-11-28",
  "User-Agent" => "Bare-Systems-homebrew-tap-updater"
}.freeze

def github_json(path)
  with_retries("#{GITHUB_API}#{path}") do |url|
    URI.open(url, GITHUB_HEADERS) do |io|
      JSON.parse(io.read)
    end
  end
end

def with_retries(url)
  attempts = 0

  begin
    attempts += 1
    yield url
  rescue OpenURI::HTTPError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
    raise if attempts >= 3

    warn "retrying #{url}: #{e.message}"
    sleep attempts
    retry
  end
end

def release_for(tag)
  if tag
    github_json("/releases/tags/#{tag}")
  else
    github_json("/releases/latest")
  end
end

def release_asset(release, name)
  release.fetch("assets").find { |asset| asset.fetch("name") == name } ||
    abort("release #{release.fetch("tag_name")} is missing #{name}")
end

def checksums_for(release)
  asset = release_asset(release, "tardigrade-checksums.txt")

  with_retries(asset.fetch("browser_download_url")) do |url|
    URI.open(url) do |io|
      io.each_line.with_object({}) do |line, checksums|
        digest, path = line.split(/\s+/, 2)
        next unless digest && path

        checksums[File.basename(path.strip)] = digest
      end
    end
  end
end

def required_checksum(checksums, archive)
  checksums.fetch(archive) do
    abort("checksum manifest is missing #{archive}")
  end
end

release = release_for(ARGV[0])
tag = release.fetch("tag_name")
checksums = checksums_for(release)

linux_aarch64 = "tardigrade-linux-aarch64.tar.gz"
linux_x86_64 = "tardigrade-linux-x86_64.tar.gz"
missing_assets = [linux_aarch64, linux_x86_64].reject do |name|
  release.fetch("assets").any? { |asset| asset.fetch("name") == name }
end
abort("release #{tag} is missing #{missing_assets.join(", ")}") unless missing_assets.empty?

formula = <<~RUBY
  class Tardigrade < Formula
    desc "Host-native Zig edge server and reverse proxy"
    homepage "https://github.com/#{REPO}"
    license "Apache-2.0"

    depends_on :linux

    on_linux do
      on_arm do
        url "https://github.com/#{REPO}/releases/download/#{tag}/#{linux_aarch64}"
        sha256 "#{required_checksum(checksums, linux_aarch64)}"
      end

      on_intel do
        url "https://github.com/#{REPO}/releases/download/#{tag}/#{linux_x86_64}"
        sha256 "#{required_checksum(checksums, linux_x86_64)}"
      end
    end

    def install
      bin.install "tardi"
      bin.install "tardigrade" if (buildpath/"tardigrade").exist?

      prefix.install "LICENSE"
      prefix.install "README.md"
      prefix.install "CHANGELOG.md"
      prefix.install "PACKAGING.md"
    end

    test do
      assert_match version.to_s, shell_output("\#{bin}/tardi version")
      assert_match version.to_s, shell_output("\#{bin}/tardigrade version")

      linked_libraries = shell_output("ldd \#{bin}/tardi")
      refute_match(/lib(?:ssl|crypto)\\.so/, linked_libraries)

      (testpath/"public").mkpath
      (testpath/"public/index.html").write "ok\\n"
      port = free_port
      (testpath/"tardigrade.conf").write <<~EOS
        listen \#{port};
        server_name localhost;

        root \#{testpath}/public;

        location = /health {
            return 200 ok;
        }
      EOS

      system bin/"tardi", "check", testpath/"tardigrade.conf"

      pid = fork do
        exec bin/"tardi", "run", "-c", testpath/"tardigrade.conf"
      end

      begin
        assert_equal "ok", shell_output("curl -fsS --retry 20 --retry-all-errors --retry-delay 1 " \\
                                        "http://127.0.0.1:\#{port}/health").strip
      ensure
        begin
          Process.kill("TERM", pid)
          Process.wait(pid)
        rescue Errno::ESRCH, Errno::ECHILD
          nil
        end
      end
    end
  end
RUBY

File.write(FORMULA_PATH, formula)
puts "updated Formula/tardigrade.rb to #{tag}"
