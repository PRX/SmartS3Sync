require 'smart_s3_sync/version'
require 'smart_s3_sync/file_table'
require 'fog'

Fog.credentials = { :path_style => true }

module SmartS3Sync

  def self.sync(dir, remote_dir, connection_options, remote_prefix=nil)
    table = FileTable.new(dir, remote_prefix)

    bucket = Fog::Storage.new(connection_options).directories.
      get(remote_dir, {:prefix => remote_prefix})

    # Add all files in the cloud to our map.
    print "Checking Files: 0"
    checked = 0
    bucket.files.each do |file|
      table.push(file)
      print "\b" * checked.to_s.length
      print (checked += 1).to_s
    end

    puts "\n"
    puts "Status: Need to download #{table.to_download.length} files (#{table.to_download.map(&:size).inject(&:+)} bytes)"
    puts "Status: with an effective total of #{table.to_copy.length} files (#{table.to_copy.map{|x| x.size * x.destinations.length }.inject(&:+)} bytes)"

    # And copy them to the right places
    table.copy!(bucket)

    # sweep through and remove all files not in the cloud
    Dir[File.join(dir, '**/*')].each do |file|
      if !File.directory?(file)
        File.unlink(file) and puts "DELETING: #{file}" unless table.keep?(file)
      end
    end

    # and then all empty directories
    Dir[File.join(dir, '**/*')].each do |file|
      if File.directory?(file) && Dir.entries(file).length == 0
        puts "DELETING: #{file}"
        Dir.rmdir(file)
      end
    end
  end

end
