class Quarkdown < Formula
  desc "A modern Markdown-based typesetting system"
  homepage "https://github.com/iamgio/quarkdown"
  version "2.7.0"
  license "GPL-3.0"

  on_macos do
    on_arm do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.7.0/quarkdown-macos-aarch64.zip"
      sha256 "60afe5ab3d2dad10355eea2ec9ca477f229c6f4c5be27a4d0338b5ed00add919"
    end

    on_intel do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.7.0/quarkdown-macos-x64.zip"
      sha256 "b0ea3cb964f6d6e0b64a32db88c1eb40615fe851d2a153019b260123d8f550c0"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.7.0/quarkdown-linux-aarch64.zip"
      sha256 "7ab347a0367d9402f65bc47f9495ae35d1d4c9ecdc52c4d5f94f40ce6f8b3960"
    end

    on_intel do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.7.0/quarkdown-linux-x64.zip"
      sha256 "5ff4e78e391abd073e62030da816faef265d681d3b8ccfd05768cc9c586f7e85"
    end
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
