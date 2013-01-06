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

while true
	File.write 'keepalive', Time.now.to_i.to_s
	task = $db.read.last
	sleep 5
	next if !task
	
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
		# create a simple object for managing the progress of the task
		progressor = {}
		progressor.send :instance_variable_set, :@task, task
		def progressor.increment
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
		
		begin
			s.summary = [
				"robot pracowicie",
				"#{Mrowka[:tasks][task.type][:summary].call task.args}",
				"(#{task.desc && !task.desc.strip.empty? ? task.desc : "brak opisu"})",
				"[operator: [[User:#{task.user}|#{task.user}]]]"
			].join(" ")
			Mrowka[:tasks][task.type][:process].call s, s.make_list(:pages, task.list), progressor, task.args
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
