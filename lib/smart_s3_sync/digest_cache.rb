require 'sqlite3'
require 'digest/md5'

module SmartS3Sync
  module DigestCache
    class << self
      def digest(filename)
        if (cr = cache_record(filename)) && File.mtime(filename).to_i <= cr[0]
          cr[1]
        else
          Digest::MD5.file(filename).hexdigest.tap do |digest|
            save_record(filename, File.mtime(filename).to_i, digest)
          end
        end
      end

      def save_record(filename, mtime, digest)
        database.execute("INSERT OR REPLACE INTO files (filename, mtime, digest) VALUES (?, ?, ?)", [filename, mtime, digest])
      end

      private

      def cache_record(filename)
        crow = nil
        database.execute("SELECT mtime, digest FROM files WHERE filename = ? LIMIT 1", [filename]) do |row|
          crow = row
        end
        crow
      end

      def database
        @database ||= SQLite3::Database.new(database_filename).tap do |db|
          if db.execute("SELECT COUNT(name) FROM sqlite_master WHERE type='table' AND name='files'")[0][0] < 1
            db.execute %{
              CREATE TABLE files (
                filename TEXT PRIMARY KEY,
                mtime DATETIME,
                digest VARCHAR(255)
              )
            }
          end
        end
      end

      def database_filename
        File.expand_path('.filescache.db', '~')
      end
    end
  end
end
