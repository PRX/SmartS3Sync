require 'tempfile'
require 'smart_s3_sync/digest_cache'

module SmartS3Sync
  class FileTarget
    attr_reader :digest, :remote_filename, :local_source, :destinations, :size

    def initialize(digest, remote_filename, size)
      @digest          = digest
      @size            = size
      @remote_filename = remote_filename
      @local_source    = nil
      @destinations    = []
    end

    def add_destination(file)
      unless destinations.include?(file)
        # If we already have a local file with the right checksum,
        # we don't add it to the list of destinations and instead
        # mark it as a local source.
        if File.exists?(file) && file_hash(file) == digest.to_s
          add_local_source(file)
        else
          destinations.push(file)
        end
      end
    end

    def copy!(fog_dir, sync_options={})
      # If every copy in the cloud is already present, the
      # number of destinations will be 0 - there is no work
      # left to do.
      if destinations.length > 0
        if local_source.nil?     # we prefer to not have to download
          copy_from_fog(fog_dir, sync_options)
        else
          copy_from_local(local_source, sync_options)
        end
      end
    end

    private

    def copy_from_fog(fog_dir, sync_options={})
      $stderr.puts "Downloading #{remote_filename}"
      tries = 0
      file = nil
      begin
        file = download(fog_dir, sync_options) # basically, just try.

        if file_hash(file.path) != digest.to_s
          raise "Hash mismatch downloading #{remote_filename}"
        end

        copy_from_local(file.path, sync_options) # with a copy locally, the job is the same
        @local_source = destinations.shift # we now have a local copy!
      rescue StandardError => e
        if tries < 5
          tries += 1
          $stderr.puts e
          $stderr.puts "retrying"
          retry
        else
          raise e
        end
      ensure
        file.close(true) unless file.nil?
      end
    end

    def copy_from_local(source, sync_options={})
      $stderr.puts "Linking #{destinations.join(', ')}"
      destinations.each do |dest|
        FileUtils.mkdir_p(File.dirname(dest), :mode => 0755)
        FileUtils.ln(source, dest, :force => true)
        DigestCache.save_record(dest, File.mtime(dest).to_i, digest.to_s)
      end
    end

    def add_local_source(file)
      if local_source.nil?
        @local_source = file
      else
        FileUtils.ln(local_source, file, :force => true)
      end
    end

    def file_hash(path)
      DigestCache.digest(path)
    end

    def download(fog_dir, sync_options={})
      dir = File.dirname(destinations[0])
      FileUtils.mkdir_p(dir)
      Tempfile.new(".#{digest}", dir).tap do |file|
        rfile = fog_dir.files.get(remote_filename) do |chunk, left, total|
          if (chunk.size + left == total) # fog might restart in the middle
            file.rewind
          end

          file.write chunk
        end
        file.close
        File.chmod(0644, file.path)
        if sync_options.has_key?('set-timestamp-from-metadata')
          time = rfile.metadata[sync_options['set-timestamp-from-metadata']]
          time &&= Time.at(time.to_i)
          time && File.utime(time, time, file)
        end
      end
    end
  end
end
