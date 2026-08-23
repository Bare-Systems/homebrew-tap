class Tardigrade < Formula
  desc "Host-native Zig edge server and reverse proxy"
  homepage "https://github.com/Bare-Systems/Tardigrade"
  license "Apache-2.0"

  depends_on :linux

  on_linux do
    on_arm do
      url "https://github.com/Bare-Systems/Tardigrade/releases/download/v0.5.0/tardigrade-linux-aarch64.tar.gz"
      sha256 "204cd9c85dfc225a68704eab7b20d900b8ddaa7df8da123463e4a969cb569c38"
    end

    on_intel do
      url "https://github.com/Bare-Systems/Tardigrade/releases/download/v0.5.0/tardigrade-linux-x86_64.tar.gz"
      sha256 "0d81db140b18bf3a717923416f83009285d267b5bc9e99132e51f210a5447b4d"
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
    assert_match version.to_s, shell_output("#{bin}/tardi version")
    assert_match version.to_s, shell_output("#{bin}/tardigrade version")

    linked_libraries = shell_output("ldd #{bin}/tardi")
    refute_match(/lib(?:ssl|crypto)\.so/, linked_libraries)

    (testpath/"public").mkpath
    (testpath/"public/index.html").write "ok\n"
    port = free_port
    (testpath/"tardigrade.conf").write <<~EOS
      listen #{port};
      server_name localhost;

      root #{testpath}/public;

      location = /health {
          return 200 ok;
      }
    EOS

    system bin/"tardi", "check", testpath/"tardigrade.conf"

    pid = fork do
      exec bin/"tardi", "run", "-c", testpath/"tardigrade.conf"
    end

    begin
      assert_equal "ok", shell_output("curl -fsS --retry 20 --retry-all-errors --retry-delay 1 " \
                                      "http://127.0.0.1:#{port}/health").strip
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
