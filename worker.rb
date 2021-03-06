# coding: utf-8

require 'io/console'
require 'sunflower'

require_relative 'config'
require_relative 'tasks'

require_relative 'models'

module Mrowka
	module Worker
		# A class for worker<->task interfacing.
		class Interface
			attr_accessor :task
			
			def initialize task
				@task = task
			end
			
			# Increments the progress.
			def increment n=1
				@prog ||= 0
				@prog += n
				
				@task.change_done = @prog
				@task.save
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
					- summ.zip(priorities).map{|part, prio| part ? part.bytes.to_a.length * (inv - prio) : 0 }.inject(:+)
				}
				
				# take the first one that fits within 255 bytes, or last
				summ = possib.find{|summ| summ.compact.join(" ").bytes.to_a.length <= 255 } || possib.last
				return summ.compact.join(" ")
			end
		end

		def self.run
			print "Pass? "
			s = Sunflower.new(Mrowka::Config['worker']['botwiki'])
			s.login(Mrowka::Config['worker']['botusername'], STDIN.noecho{gets.strip})
			puts ''

			while true
				File.write 'keepalive', Time.now.to_i.to_s
				task = Mrowka::Models::Task.all.find{|t| t.status != 'done' && t.status != 'error'} # TODO all?
				sleep 5
				next if !task
				
				# if too many edits made in last 24 hours, stop.
				if Mrowka::Models::Task.all.select{|task| !task.touched || Time.now-task.touched < 24*60*60 }.map{|task| task.change_done }.compact.inject(0, :+) >= Mrowka::Config['worker']['dailylimit'].to_i
					puts "Daily limit exceeded. Sleeping for 30 minutes..."
					sleep 60*30
					next
				end
				
				print "Task #{task.md5}: #{task.status}... "
				
				case task.status
				when 'waiting'
					# valid - user is allowed to do this, don't cancel this task
					# confirmed - user confirmed he does in fact want to perform this task, do it
					valid = confirmed = nil
					
					if task.definition[:edits] == false
						valid = confirmed = true
					else
						whitelist = File.readlines('whitelist.txt').map(&:strip)
						
						if whitelist.include? task.user
							valid = true
							
							page = s.page "User:#{task.user}/mrówka.js"
							if page.text.strip == task.md5.to_s
								confirmed = true
							else
								confirmed = false
							end
						else
							valid = confirmed = false
						end
					end
					
					if valid.nil? || confirmed.nil?
						raise "shouldn't happen"
					elsif valid && confirmed
						task.status = 'queued'
					elsif valid && !confirmed
						if task.started < Time.now - 60*60
							task.status = 'error'
							task.error_message = "<expired (not confirmed for 60m)>"
						else
							# pass
						end
					elsif !valid && !confirmed
						task.status = 'error'
						task.error_message = "<user not allowed to perform this task>"
					elsif !valid && confirmed
						raise "shouldn't happen"
					end
				
				when 'queued'
					begin
						if task.definition[:make_list]
							list = task.definition[:make_list].call s, task.args
						elsif task.definition[:external_list] == true
							# TODO force update?
							list = Mrowka::Models::List.find(id: task.external_list_id).contents
						else
							list = []
						end
					rescue => e
						list = nil
					end
					
					if list
						task.list = list.to_a
						task.change_total = list.length
						task.status = 'inprogress'
					else
						task.status = 'error'
						task.error_message = ([e.message]+e.backtrace).inspect
					end
					
				when 'inprogress'
					interface = Mrowka::Worker::Interface.new task
					
					begin
						task.definition[:process].call s, s.make_list(:pages, task.list), interface, task.args
						okay = true
					rescue => e
						okay = false
					end
					s.summary = nil
					
					if okay
						task.status = 'done'
					else
						task.status = 'error'
						task.error_message = ([e.message]+e.backtrace).inspect
					end
					
				when 'done', 'error'
					# do nothing
				
				else
					raise
				end
				
				
				task.touched = Time.now
				
				task.save
				print "-> #{task.status}\n"
			end
		end
	end
end

if __FILE__ == $0
	Mrowka::Worker.run
end
