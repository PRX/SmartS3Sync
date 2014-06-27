require 'tempfile'
require 'smart_s3_sync/digest_cache'

module SmartS3Sync
  class FileTarget
    attr_reader :digest, :remote_filename, :local_source, :destinations

    def initialize(digest, remote_filename)
      @digest          = digest
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
          puts "#{file} is up to date"
          @local_source = file
        else
          destinations.push(file)
        end
      end
    end

    def copy!(fog_dir)
      # If every copy in the cloud is already present, the
      # number of destinations will be 0 - there is no work
      # left to do.
      if destinations.length > 0
        if local_source.nil?     # we prefer to not have to download
          copy_from_fog(fog_dir)
        else
          copy_from_local(source)
        end
      end
    end

    private

    def copy_from_fog(fog_dir)
      puts "Downloading #{remote_filename}."
      tries = 0
      file = nil
      begin
        file = download(fog_dir) # basically, just try.

        if file_hash(file.path) != digest.to_s
          raise "Hash mismatch downloading #{remote_filename}"
        end

        copy_from_local(file.path) # with a copy locally, the job is the same
        @local_source = destinations.shift # we now have a local copy!
      rescue StandardError => e
        if tries < 5
          tries += 1
          puts e
          puts "retrying"
          retry
        else
          raise e
        end
      ensure
        file.close(true) unless file.nil?
      end
    end

    def copy_from_local(source)
      destinations.each do |dest|
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.ln(source, dest, :force => true)
        DigestCache.save_record(dest, File.mtime(dest).to_i, digest.to_s)
      end
    end

    def file_hash(path)
      DigestCache.digest(path)
    end

    def download(fog_dir)
      file = Tempfile.new(digest.to_s)
      done = 0
      now = Time.now.to_i

      fog_dir.files.get(remote_filename) do |chunk, left, total|
        if (chunk.bytes.size + left == total) # fog might restart in the middle
          file.rewind
          if done !=0
            puts " ERROR ... retrying"
            done = 0
          end
        end

        file.write chunk
        (((1 - (left.to_f / total)) * 50).to_i - done).times do
          done += 1
          print "#"
        end
        if done == 50
          done = total / 1048576.to_f
        end
      end

      puts " #{((done / [Time.now.to_i - now, 0.5].max) * 100).to_i / 100.0} MB/s"
      file.close
      file
    end
  end
end
