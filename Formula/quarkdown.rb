class Quarkdown < Formula
  desc "A modern Markdown-based typesetting system"
  homepage "https://github.com/iamgio/quarkdown"
  url "https://github.com/iamgio/quarkdown/archive/refs/tags/v1.5.1.tar.gz"
  sha256 "a7d5886baf4c683e58be17bb5256be489db9ad91a983c0e61e6366fce319ece6"
  license "GPL-3.0"

  depends_on "openjdk@17"
  depends_on "node"
  # depends_on "chromium" # Ensure Chromium is installed for Puppeteer

  def install
      ENV["JAVA_HOME"] = Formula["openjdk@17"].opt_prefix
      env["PUPPETEER_CHROME_SKIP_DOWNLOAD"] = "true"

      # Build the distribution ZIP using Gradle
      system "./gradlew", "distZip"

      # Find and unzip the dist output
      dist_zip = Dir["build/distributions/*.zip"].first
      odie "distZip output not found" unless dist_zip
      system "unzip", dist_zip, "-d", "dist"

      dist_folder = Dir["dist/*"].find { |f| File.directory?(f) }
      odie "Unzipped dist folder not found" unless dist_folder

      # Install app files
      libexec.install Dir["#{dist_folder}/*"]

      # Install Puppeteer with Chromium bundled
      system "npm", "install", "-g", "puppeteer", "--prefix", libexec

      # Create the CLI wrapper
      (bin/"quarkdown").write <<~EOS
        #!/bin/bash
        export JAVA_HOME=#{Formula["openjdk@17"].opt_prefix}
        export PATH=#{Formula["node"].opt_bin}:#{libexec}/bin:$PATH
        export PUPPETEER_EXECUTABLE_PATH="#{Formula["chromium"].opt_bin}/chromium"
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