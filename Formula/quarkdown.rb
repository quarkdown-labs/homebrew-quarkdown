class Quarkdown < Formula
  desc "A modern Markdown-based typesetting system"
  homepage "https://github.com/iamgio/quarkdown"
  version "2.6.2"
  license "GPL-3.0"

  on_macos do
    on_arm do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.6.2/quarkdown-macos-aarch64.zip"
      sha256 "3b11d2b61c1f5ca33b5b0e0102e71202d3f37bb0538aca719b88930cf40fa3ca"
    end

    on_intel do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.6.2/quarkdown-macos-x64.zip"
      sha256 "043e4162589221b5e4b909eebe7d63399942728af75d931f9dadb3cc06f67edc"
    end
  end

  on_linux do
    url "https://github.com/iamgio/quarkdown/releases/download/v2.6.2/quarkdown-linux-x64.zip"
    sha256 "84314977298511662c3053f7c1d24c0236ff19c5baa07807142fc034d7ae24fa"
  end

  def install
    # Install pre-built app files (bin/ and lib/) from the extracted zip
    libexec.install Dir["*"]

    # Homebrew's keg-relocation pass rewrites every Mach-O install name in the
    # keg to an absolute /opt/homebrew/... path. That invalidates the JVM's
    # bundled code signatures, and Apple Silicon's loader refuses to dlopen the
    # mutated dylibs -- the VM then crashes at PC=0 during init. Stash the
    # runtime/ tree as a tarball (which the relocation pass ignores) and
    # restore it in post_install, after relocation has run.
    cd libexec do
      system "tar", "-czf", "runtime-stash.tar.gz", "runtime"
    end

    # Create the CLI wrapper
    (bin/"quarkdown").write <<~EOS
      #!/bin/bash
      export PATH=#{libexec}/bin:$PATH
      export QD_CHROME_PATH=#{headless_shell_root}/chrome-headless-shell-#{headless_shell_platform}/chrome-headless-shell
      exec #{libexec}/bin/quarkdown "$@"
    EOS
    chmod 0755, bin/"quarkdown"
  end

  def post_install
    # Restore the runtime tree from the stash, undoing Homebrew's relocation.
    cd libexec do
      rm_rf "runtime"
      system "tar", "-xzf", "runtime-stash.tar.gz"
      rm "runtime-stash.tar.gz"
    end

    install_headless_shell
  end

  # Chrome for Testing platform identifier of the current host.
  def headless_shell_platform
    if OS.mac?
      Hardware::CPU.arm? ? "mac-arm64" : "mac-x64"
    else
      "linux64"
    end
  end

  # Directory the chrome-headless-shell bundle is extracted into.
  def headless_shell_root
    libexec/"chrome-headless-shell"
  end

  # Downloads chrome-headless-shell, the headless browser required for PDF export,
  # via the installer script shipped with the distribution (which pins its version).
  def install_headless_shell
    script = libexec/"scripts/install-chrome.sh"
    unless script.exist?
      opoo "This Quarkdown release does not ship a browser installer. PDF export may require a manual browser setup."
      return
    end

    rm_rf headless_shell_root
    system "bash", script, headless_shell_root
  end

  test do
      test_dir = "test"
      test_file = "test.qd"
      output_dir = "output"
      quarkdown = bin/"quarkdown"

      require 'fileutils'
      FileUtils.mkdir_p(test_dir)
      File.write("#{test_dir}/#{test_file}", ".docname {test}")

      system quarkdown, "c", "#{test_dir}/#{test_file}", "-o", "./#{output_dir}"
      assert_path_exists testpath/output_dir, "Output directory does not exist"
  end
end
