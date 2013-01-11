# coding: utf-8

require_relative 'mrowka-defs'

require 'io/console'
require 'sunflower'

require_relative 'filebackend'
require_relative 'mrowka-task'

$db = FileBackend.new 'data-marshal', 'data-marshal.lock'
$dbarchive = FileBackend.new 'dataarchive-marshal', 'dataarchive-marshal.lock'

$db.write([]) if !$db.exist?
$dbarchive.write([]) if !$dbarchive.exist?

print "Pass? "
s = Sunflower.new('w:pl').login('MatmaBot', STDIN.noecho{gets.strip})
puts ''

# A class for worker<->task interfacing.
class MrowkaWorkerInterface
	attr_accessor :task
	
	def initialize task
		@task = task
	end
	
	# Increments the progress.
	def increment
		@prog ||= 0
		@prog += 1
		
		@task.status.change_done = @prog
		
		if @prog % 10 == 0 or @prog == @task.status.change_total
			$db.transact do |data|
				data[0].status.change_done = @prog
				data
			end
		end
	end
	
	# Generates a full summary including the core part.
	# 
	# Tries hard to get it to fit in 255 bytes.
	def summary *bases
		# define variants of summary parts, in decreasing length
		summ = [
			["robot pracowicie", "robot"],
			bases.sort_by{|a| -a.bytes.to_a.length },
			[(task.desc && !task.desc.strip.empty?) ? "(#{task.desc})" : nil],
			["[operator: [[User:#{task.user}|#{task.user}]]]", "[operator: #{task.user}]", "[#{task.user}]"]
		]
		
		# how important it is to keep parts at given indices intact
		priorities = [1, 5, 10, 3]
		inv = priorities.max + 1
		
		# compute all possible summaries and rank them by sum of length of parts, weighted by priorities
		possib = summ[0].product(*summ[1..-1])
		possib = possib.sort_by{|summ|
			- summ.zip(priorities).map{|part, prio| part.bytes.to_a.length * (inv - prio) }.inject(:+)
		}
		
		# take the first one that fits within 255 bytes, or last
		summ = possib.find{|summ| summ.compact.join(" ").bytes.to_a.length <= 255 } || possib.last
		return summ.compact.join(" ")
	end
end

while true
	File.write 'keepalive', Time.now.to_i.to_s
	task = $db.read.last
	sleep 5
	next if !task
	
	# if more than 1000 edits made in last 24 hours, stop.
	if ($db.read + $dbarchive.read).select{|task| !task.finished || Time.now-task.finished < 24*60*60 }.map{|task| task.status.change_done }.compact.inject(0, :+) >= 1000
		puts "Daily limit exceeded. Sleeping for 30 minutes..."
		sleep 60*30
		next
	end
	
	print "Task #{task.hash}: #{task.status.state}... "
	
	case task.status.state
	when :waiting
		resp = s.API("action=query&list=users&format=json&usprop=groups&ususers=#{CGI.escape task.user}")
		
		if ( ( resp['query']['users'].first || {} )['groups'] || [] ).include? 'sysop'
			page = s.page "User:#{task.user}/mrówka.js"
			if page.text.strip == task.hash.to_s
				task.status.state = :queued
			end
		else
			task.status.state = :error
			task.status.error_message = "<user not a sysop>"
		end
		
	when :queued
		begin
			list = Mrowka[:tasks][task.type][:make_list].call s, task.args
		rescue => e
			list = nil
		end
		
		if list
			task.list = list.to_a
			task.status.change_total = list.length
			task.status.state = :inprogress
		else
			task.status.state = :error
			task.status.error_message = e.message
		end
		
	when :inprogress
		interface = MrowkaWorkerInterface.new task
		
		begin
			Mrowka[:tasks][task.type][:process].call s, s.make_list(:pages, task.list), interface, task.args
			okay = true
		rescue => e
			okay = false
		end
		s.summary = nil
		
		if okay
			task.status.state = :done
		else
			task.status.state = :error
			task.status.error_message = e.message
		end
		
	when :done, :error
		# do nothing
		
	end
	
	
	task.finished = Time.now
	
	print "-> #{task.status.state}\n"
	
	if task.status.state == :done or task.status.state == :error
		# move to archive
		$db.transact do |data|
			$dbarchive.transact do |data_ar|
				data_ar.push task
				data_ar
			end
			data.pop
			data
		end
	else
		# update
		$db.transact do |data|
			data[0] = task
			data
		end
	end
end
