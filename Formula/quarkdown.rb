class Quarkdown < Formula
  desc "A modern Markdown-based typesetting system"
  homepage "https://github.com/iamgio/quarkdown"
  version "2.4.1"
  license "GPL-3.0"

  on_macos do
    on_arm do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.4.1/quarkdown-macos-aarch64.zip"
      sha256 "40ceb1f6e4e9b3ca4953cb3d5d6c8837f84db9dff3a9bfa56f63cdd1008ca232"
    end

    on_intel do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.4.1/quarkdown-macos-x64.zip"
      sha256 "115514277d44185531cc7a1f2387bade2ecadcddb802b6c7c95d5321cd312846"
    end
  end

  on_linux do
    url "https://github.com/iamgio/quarkdown/releases/download/v2.4.1/quarkdown-linux-x64.zip"
    sha256 "f6161298a2d0e7139ab405474495e9b188979e2ff1e761638bdb17ae1c0cb2b1"
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
