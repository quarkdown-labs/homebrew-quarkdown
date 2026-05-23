class Quarkdown < Formula
  desc "A modern Markdown-based typesetting system"
  homepage "https://github.com/iamgio/quarkdown"
  version "2.1.0"
  license "GPL-3.0"

  on_arm do
    url "https://github.com/iamgio/quarkdown/releases/download/v2.1.0/quarkdown-macos-aarch64.zip"
    sha256 "3cc7f690515e7e92c56864fca9b105a07f01494be374e941fc80610537cc274d"
  end

  on_intel do
    url "https://github.com/iamgio/quarkdown/releases/download/v2.1.0/quarkdown-macos-x64.zip"
    sha256 "6201dda507fbdf5d28122b8559287457503eead8249f42f179325fc512deda5b"
  end

  depends_on "node"

  def install
    # Install pre-built app files (bin/ and lib/) from the extracted zip
    libexec.install Dir["*"]

    # The bundled runtime is built via cross-compiled jlink on Linux, so its
    # Mach-O binaries arrive unsigned. Apple Silicon refuses to execute native
    # code without at least an ad-hoc signature, so re-sign the runtime here.
    system "codesign", "--force", "--deep", "--sign", "-", libexec/"runtime"

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
