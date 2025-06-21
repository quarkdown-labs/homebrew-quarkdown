class Quarkdown < Formula
  desc "A modern Markdown-based typesetting system"
  homepage "https://github.com/iamgio/quarkdown"
  url "https://github.com/iamgio/quarkdown/archive/refs/tags/v1.5.0.tar.gz"
  sha256 "2e4b17e3ba72dea93b7c5c7053b519b158d840efd5ed8ac3cf15942c4b27cfe2"
  license "GPL-3.0"

  depends_on "openjdk@17"
  depends_on "node"

  def install
      ENV["JAVA_HOME"] = Formula["openjdk@17"].opt_prefix
      ENV["PUPPETEER_CHROME_SKIP_DOWNLOAD"] = "true"

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

      # Install Puppeteer (without bundling Chrome)
      system "npm", "install", "-g", "puppeteer", "--prefix", libexec

      # Create the CLI wrapper
      (bin/"quarkdown").write <<~EOS
        #!/bin/bash
        export JAVA_HOME=#{Formula["openjdk@17"].opt_prefix}
        export PATH=#{Formula["node"].opt_bin}:#{libexec}/bin:$PATH
        export NPM_GLOBAL_PREFIX=#{libexec}
        exec #{libexec}/bin/quarkdown "$@"
      EOS
      chmod 0755, bin/"quarkdown"
    end

  def caveats
    <<~EOS
      In order to compile to PDF, Quarkdown requires Chrome, Chromium or Firefox installed.
      If you don't have any of these browsers installed:

        brew install --cask google-chrome

      PDF generation will fail if a browser is not found at runtime.
    EOS
  end

  test do
      test_dir = "test"
      output_dir = "output"
      quarkdown = bin/"quarkdown"
      system quarkdown, "create", test_dir
      system quarkdown, "c", "#{test_dir}/test.qd", "--output", "./#{output_dir}"
      assert_path_exists testpath/output_dir, "Output directory does not exist"
  end
end