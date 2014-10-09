require 'smart_s3_sync/version'
require 'smart_s3_sync/file_table'
require 'fog'

Fog.credentials = { :path_style => true }

module SmartS3Sync

  def self.sync(dir, remote_dir, connection_options, remote_prefix=nil, sync_options={})
    table = FileTable.new(dir, remote_prefix)

    bucket = Fog::Storage.new(connection_options).directories.
      get(remote_dir, {:prefix => remote_prefix})

    # Add all files in the cloud to our map.
    $stderr.print "Checking Files: "
    checked = 0
    bucket.files.each do |file|
      table.push(file)
      if $stderr.tty?
        $stderr.print "\b" * checked.to_s.length unless checked == 0
        $stderr.print (checked += 1).to_s
      elsif (checked += 1) == 1
        $stderr.print '...'
      elsif checked % 1000 == 0
        $stderr.print '.'
      end
    end

    $stderr.puts " done! (#{checked} files)\n"
    $stderr.puts "Status: Need to download #{table.to_download.length} files (#{table.to_download.map(&:size).inject(&:+)} bytes)"
    $stderr.puts "Status: with an effective total of #{table.to_copy.inject(0){|coll, obj| coll + obj.destinations.length }} files (#{table.to_copy.map{|x| x.size * x.destinations.length }.inject(&:+)} bytes)"

    # And copy them to the right places
    table.copy!(bucket, sync_options)

    # sweep through and remove all files not in the cloud
    Dir.glob(File.join(dir, '**/*')) do |file|
      if !File.directory?(file)
        File.unlink(file) and $stderr.puts "DELETING: #{file}" unless table.keep?(file)
      end
    end

    # and then all empty directories
    Dir.glob(File.join(dir, '**/*')) do |file|
      if File.directory?(file) && Dir.entries(file).length == 0
        $stderr.puts "DELETING: #{file}"
        Dir.rmdir(file)
      end
    end
  end

end
