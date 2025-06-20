class Quarkdown < Formula
  desc "A modern Markdown-based typesetting system"
  homepage "https://github.com/iamgio/quarkdown"
  url "https://github.com/iamgio/quarkdown/archive/refs/tags/v1.5.1.tar.gz"
  sha256 "a7d5886baf4c683e58be17bb5256be489db9ad91a983c0e61e6366fce319ece6"
  license "GPL-3.0"

  depends_on "openjdk@17"
  depends_on "node"

  def install
    ENV["JAVA_HOME"] = Formula["openjdk@17"].opt_prefix
    ENV["PUPPETEER_SKIP_CHROMIUM_DOWNLOAD"] = "true"

    # Install to libexec
    libexec.install Dir["*"]

    # Install puppeteer inside the formula directory
    cd libexec do
      system "npm", "install", "-g", "puppeteer", "--prefix", libexec
    end

    # Create a wrapper script
    (bin/"quarkdown").write <<~EOS
      #!/bin/bash
      export JAVA_HOME=#{Formula["openjdk@17"].opt_prefix}
      export PATH=#{Formula["node"].opt_bin}:#{libexec}/bin:$PATH
      exec #{libexec}/bin/quarkdown "$@"
    EOS
    chmod 0755, bin/"quarkdown"
  end

#   def caveats
#     <<~EOS
#       Puppeteer is installed locally to avoid global install issues.
#       Chromium download is disabled. If needed, set PUPPETEER_EXECUTABLE_PATH.
#     EOS
#   end

  test do
      test_dir = "test"
      system bin/"quarkdown", "create", test_dir
      system bin/"quarkdown", "c", "#{test_dir}/test.qd"
      assert_path_exists testpath/"output", "Output directory does not exist"
  end
end