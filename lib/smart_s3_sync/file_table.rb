require 'smart_s3_sync/file_target'

module SmartS3Sync
  class FileTable
    def initialize(root, prefix=nil)
      @map    = {} # map of hashes to file destinations
      @files  = [] # single list of files to keep
      @root   = File.expand_path(root) # root file destination
      @prefix =  prefix ? prefix.gsub(/(?:^\/)|(?:\/$)/,'') : ''
    end

    def push(fog_file)
      digest = hash_key(fog_file) # pull cloud calculated hex digest from file
      @map[digest] ||= FileTarget.new(digest, fog_file.key, fog_file.content_length) # grab or create target
      destination_filename = File.expand_path(strip_prefix(fog_file.key), @root) # calculate local path
      @files.push destination_filename # add local path to global list of files to keep
      @map[digest].add_destination(destination_filename) # and add local path to the target
    end

    def copy!(fog_dir, sync_options={})
      @map.sort_by do |(k, target)|
        1_000_000_000 * (target.local_source.nil? ? 0 : -1) -
            1_000_000 * target.destinations.length +
          1/1_048_576 * target.size
      end.each do |(k, target)|
        target.copy!(fog_dir, sync_options)
      end
    end

    def keep?(filename)
      @files.include?(filename)
    end

    def to_copy
      @_tc ||= @map.select {|key, target| target.destinations.length > 0 }.map{|x, y| y }
    end

    def to_download
      @_td ||= to_copy.select {|target| target.local_source.nil? }
    end

    private

    def hash_key(fog_file)
      (fog_file.content_md5 || fog_file.etag).intern # these should be equivalent
    end

    def strip_prefix(key)
      key.sub(/^#{@prefix}\/?/, '')
    end
  end
end
