require 'smart_s3_sync/version'
require 'smart_s3_sync/file_table'
require 'fog'

module SmartS3Sync

  def self.sync(bucket_name, dir, prefix=nil)
    table = FileTable.new(dir, prefix)

    bucket = Fog::Storage.new({
      :provider => 'AWS',
      :aws_access_key_id => id,
      :aws_secret_access_key => secret,
      :endpoint => 'http://s3.amazonaws.com'
    }).directories.get(bucket_name, {:prefix => prefix})


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
