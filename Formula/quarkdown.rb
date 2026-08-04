class Quarkdown < Formula
  desc "A modern Markdown-based typesetting system"
  homepage "https://github.com/iamgio/quarkdown"
  version "2.5.0"
  license "GPL-3.0"

  on_macos do
    on_arm do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.5.0/quarkdown-macos-aarch64.zip"
      sha256 "36eb07416039a1ba7a06d8db26dc4a96ac818bfc69560c422fd357a6abbf355b"
    end

    on_intel do
      url "https://github.com/iamgio/quarkdown/releases/download/v2.5.0/quarkdown-macos-x64.zip"
      sha256 "2917dc4a27d23b6bb864e1d8e23f256495c461ecfa99c8513aa736549c097825"
    end
  end

  on_linux do
    url "https://github.com/iamgio/quarkdown/releases/download/v2.5.0/quarkdown-linux-x64.zip"
    sha256 "f261e49cdb0ba420781ad8f25bb0f2422ceed6186c47f3d52ab3408d8bb30ba1"
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
