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
      @map[digest] ||= FileTarget.new(digest, fog_file.key) # grab or create target
      destination_filename = File.expand_path(strip_prefix(fog_file.key), @root) # calculate local path
      @files.push destination_filename # add local path to global list of files to keep
      @map[digest].add_destination(destination_filename) # and add local path to the target
    end

    def copy!(fog_dir)
      @map.each do |(k, target)|
        target.copy!(fog_dir)
      end
    end

    def keep?(filename)
      @files.include?(filename)
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
