class Quarkdown < Formula
  desc "A modern Markdown-based typesetting system"
  homepage "https://github.com/iamgio/quarkdown"
  version "2.1.2"
  license "GPL-3.0"

  on_macos do
    on_arm do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.1.2/quarkdown-macos-aarch64.zip"
      sha256 "26380b41b7dc1f4a16136ab1d769dccd93f2d9695699e69d9c0112fc4d6f70fc"
    end

    on_intel do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.1.2/quarkdown-macos-x64.zip"
      sha256 "0e3ad748a271077c8e6f8d1552955b5c106d69a3b9ab3445bb19c2194c2f194f"
    end
  end

  on_linux do
    url "https://github.com/iamgio/quarkdown/releases/download/v2.1.2/quarkdown-linux-x64.zip"
    sha256 "c5073172bc5b91241f9d86cfe8c454424c6a128a750ab30b8d3602a9a373a4a0"
  end

  depends_on "node"

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

    # Install Puppeteer
    ENV["PUPPETEER_CACHE_DIR"] = HOMEBREW_CACHE/"puppeteer"
    system "npm", "install", "--prefix", libexec/"lib", "puppeteer"

    # Create the CLI wrapper
    (bin/"quarkdown").write <<~EOS
      #!/bin/bash
      export PATH=#{Formula["node"].opt_bin}:#{libexec}/bin:$PATH
      export QD_NPM_PREFIX=#{libexec}/lib
      export PUPPETEER_CACHE_DIR=#{HOMEBREW_CACHE}/puppeteer
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
  end

  test do
      test_dir = "test"
      test_file = "test.qd"
      output_dir = "output"
      quarkdown = bin/"quarkdown"

      require 'fileutils'
      FileUtils.mkdir_p(test_dir)
      File.write("#{test_dir}/#{test_file}", ".docname {test}")

      system quarkdown, "c", "#{test_dir}/#{test_file}", "--output", "./#{output_dir}"
      assert_path_exists testpath/output_dir, "Output directory does not exist"
  end
end
