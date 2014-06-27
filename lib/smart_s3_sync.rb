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
    bucket.files.each { |file| table.push(file) }

    # And copy them to the right places
    table.copy!(bucket)

    # sweep through and remove all files not in the cloud
    Dir[File.join(dir, '**/*')].each do |file|
      if !File.directory?(file)
        File.unlink(file) unless table.keep?(file)
      end
    end

    # and then all empty directories
    Dir[File.join(dir, '**/*')].each do |file|
      if File.directory?(file) && Dir.entries(file).length == 0
        Dir.rmdir(file)
      end
    end
  end

end
