# coding: utf-8

class FileBackendError < StandardError; end

# Store marshalled data in a file. Use transaction to ensure consistency.
class FileBackend
	attr_accessor :datafile, :lockfile
	def initialize datafile, lockfile
		@datafile, @lockfile = datafile, lockfile
	end
	
	# Checks if the datafile exists (was initialized already).
	def exist?
		File.exist? datafile
	end
	
	def locked?
		File.exist? lockfile
	end
	def lock
		File.write lockfile, $$
	end
	def unlock
		File.delete lockfile
	end
	
	def ensure_not_locked
		raise FileBackendError, "transaction in progress" if locked?
	end
	
	def wait_not_locked
		time_slept = 0
		while locked?
			sleep 0.1
			time_slept += 0.1
			
			if time_slept > 10
				raise FileBackendError, "lock wait timeout exceeded"
			end
		end
	end
	
	def with_lock
		wait_not_locked
		lock
		yield
	ensure
		unlock if locked?
	end
	
	def lockless_read
		return Marshal.load File.binread datafile
	end
	def lockless_write data
		File.binwrite datafile, Marshal.dump(data)
	end
	
	# Read data from file (with lock).
	def read
		with_lock do
			return lockless_read
		end
	end
	# Write data to file (with lock).
	def write data
		with_lock do
			lockless_write data
		end
	end
	
	# Takes block that is yielded currect file contents and that should return
	# new data to replace the old.
	def transact
		with_lock do
			lockless_write yield(lockless_read)
		end
	end
end
