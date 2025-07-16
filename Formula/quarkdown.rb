class Quarkdown < Formula
  desc "A modern Markdown-based typesetting system"
  homepage "https://github.com/iamgio/quarkdown"
  version "1.7.0"
  url "https://github.com/iamgio/quarkdown/archive/refs/tags/v1.7.0.tar.gz"
  sha256 "dbbdca6335b3adb4176dec1a3ad2ccc5dcf02d2d607c9e8afc9152561baa7aef"
  license "GPL-3.0"

  depends_on "openjdk@17"
  depends_on "node"

  def install
      ENV["JAVA_HOME"] = Formula["openjdk@17"].opt_prefix

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

      # Install Puppeteer
      system "npm", "install", "--prefix", libexec/"lib", "puppeteer"
      system "node", "#{libexec}/lib/node_modules/puppeteer/install.js"

      # Create the CLI wrapper
      (bin/"quarkdown").write <<~EOS
        #!/bin/bash
        export JAVA_HOME=#{Formula["openjdk@17"].opt_prefix}
        export PATH=#{Formula["node"].opt_bin}:#{libexec}/bin:$PATH
        export QD_NPM_PREFIX=#{libexec}/lib
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