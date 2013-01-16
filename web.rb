# coding: utf-8

require 'camping'
require 'sunflower'

require_relative 'config'
require_relative 'tasks'
require_relative 'lists'
require_relative 'models'
require_relative 'mab-forms'

# monkey-patch
module Camping
	class << self
		def goes(m,g=TOPLEVEL_BINDING)
			Apps << a = eval(S.gsub(/Camping/,m.to_s), g)
			caller[0]=~/:/
			IO.read(a.set:__FILE__,$`)=~/^__END__/ &&
			(b=$'.split(/^@@\s*(.+?)\s*\r?\n/m)).shift rescue nil
			a.set :_t,H[*b||[]]
		end
	end
end

module Mrowka
	Camping.goes :Web, binding
	module Web
		module Controllers
			class Index
				def get
					render :index
				end
			end
			
			class Tasks
				def get
					@tasks = Mrowka::Models::Task.all
					render :tasks
				end
			end
			
			class TasksNew
				def get
					render :new_task_list
				end
			end
			
			class TasksNewX
				def get type
					@type = type.to_sym
					render :new_task_form
				end
				def post type
					DB.transaction do
						args = Mrowka::Tasks[type.to_sym][:attrs].map{|key, val| @request["taskarg_#{key}"] }
						
						task = Mrowka::Models::Task.new(
							type: type,
							desc: @request[:desc],
							args: args,
							started: Time.now,
							touched: Time.now,
							user: @request[:user],
							external_list_id: @request[:list].to_i,
							md5: nil # placeholder!
						)
						task.save # TODO dafuq? why is this necessary?
						
						task.status = Mrowka::Models::Status.new(state: 'waiting')
						task.md5 = Digest::MD5.hexdigest(task.inspect)
						task.save
					end
					
					redirect Tasks
				end
			end
			
			class Lists
				def get
					@lists = Mrowka::Models::List.all
					render :lists
				end
			end
			
			class ListsN
				def get n
					@list = Mrowka::Models::List.find id: n.to_i
					render :list
				end
			end
			
			class ListsNew
				def get
					render :new_list_list
				end
			end
			
			class ListsNewX
				def get type
					@type = type.to_sym
					render :new_list_form
				end
				def post type
					DB.transaction do
						args = Mrowka::Lists[type.to_sym][:attrs].map{|key, val| @request["taskarg_#{key}"] }
						
						list = Mrowka::Models::List.new(
							type: type,
							desc: @request[:desc],
							args: args,
							created: Time.now,
							user: @request[:user],
						)
						list.save
					end
					
					redirect Lists
				end
			end
		end
		
		module Views
			# yay constant resolution rules...
			Tasks = Controllers::Tasks
			Lists = Controllers::Lists

			def layout
				html do
					head do
						meta charset:'utf-8'
						title "Mrówka"
					end
					body do
						h1 "Mrówka"
						text! yield
					end
				end
			end
			
			def index
				p "Witaj w serwisie Mrówki. Mrówka to bot, który chętnie wykona za ciebie nudne zadania."
				p "Status: #{File.read('keepalive').to_i > Time.now.to_i - 30 ? 'działa.' : 'leży!'}"
				p "Możesz:"
				ul do
					li { a "przejrzeć listę zaproponowanych, trwających i zakończonych prac", href: R(Tasks) }
					li { a "zgłosić nową robótkę", href: R(TasksNew) }
					li { a "przejrzeć spis zdefiniowanych list", href: R(Lists) }
					li { a "utworzyć nową listę", href: R(ListsNew) }
				end
			end
			
			def tasks
				readable_status_map = {
					waiting: "Czekające na potwierdzenie",
					queued: "W kolejce",
					inprogress: "Trwa",
					error: "Błąd",
					done: "Wykonane",
				}
				
				table border:1 do
					tr do
						th "Typ"
						th "Opis"
						th "Dane wejściowe"
						th "Zgłoszone"
						th "Status"
						th "Hash"
					end
					@tasks.each do |task|
						tr do
							td task.definition[:desc]
							td task.desc
							td do
								dl do
									if task.definition[:external_list]
										dt "Lista"
										dd do
											a task.external_list.desc, href: R(ListsN, task.external_list.id)
										end
									end
									task.definition[:attrs].keys.zip(task.args) do |key, val|
										dt key
										dd val
									end
								end
							end
							td "#{task.started.to_s} przez #{task.user}"
							td "#{readable_status_map[task.status.state.to_sym]} #{task.status.state == 'error' ? task.status.error_message : nil} (#{task.status.change_done}/#{task.status.change_total || '?'})"
							td {
								text task.md5
								text ' '
								_confirm_form task if task.status.state == 'waiting' and task.definition[:edits] != false
							}
						end
					end
				end
			end
			
			def lists
				table border:1 do
					tr do
						th "Typ"
						th "Opis"
						th "Dane wejściowe"
						th "Utworzona"
						th "Wygenerowana"
						th "Zawartość"
					end
					@lists.each do |list|
						tr do
							td list.type
							td list.desc
							td do
								ul do
									list.args.each do |val|
										li val
									end
								end
							end
							td list.created
							td list.updated 
							td {
								a "Zobacz lub wygeneruj zawartość", href: R(ListsN, list.id)
							}
						end
					end
				end
			end
			
			def list
				dl do
					dt "Typ"
					dd @list.type
					dt "Opis"
					dd @list.desc
					dt "Dane wejściowe"
					dd do
						ol do
							@list.args.each do |val|
								li val
							end
						end
					end
					dt "Utworzona"
					dd @list.created
					dt "Wygenerowana"
					dd @list.updated 
					dt "Zawartość"
					dd do
						if @list.contents
							ol do
								@list.contents.each do |item|
									li item
								end
							end
						end
					end
					dt "Akcje"
					dd do
						# TODO sucks
						a "#{@list.contents ? "Wygeneruj ponownie zawartość" : "Wygeneruj zawartość"}", href: R(TasksNewX, 'list') + "?from_list=#{@list.id}"
					end
				end
			end
			
			def new_list_list
				h2 "Nowa lista"
				ul do
					Mrowka::Lists.each_pair do |key, val|
						li { a val[:desc], href:R(ListsNewX, key) }
					end
				end
			end
			
			def _confirm_form task
				_field = lambda{|k,v| input type:'hidden', name:k, value:v }
				
				# TODO this is unacceptable
				index_php = Sunflower.new(Mrowka::Config['worker']['botwiki']).api_endpoint.sub(/api\.php$/, 'index.php').sub(/^http:/, 'https:')
				
				form style: 'display:inline', method: "POST", action: index_php do
					_field.call 'title', "User:#{task.user}/mrówka.js"
					_field.call 'action', 'edit'
					_field.call 'wpSummary', "potwierdzenie zgłoszenia #{task.md5}"
					_field.call 'wpTextbox1', task.md5.to_s
					
					input type:'submit', value:'potwierdź'
				end
			end
			
			def new_task_list
				h2 "Nowe zadanie"
				ul do
					Mrowka::Tasks.each_pair do |key, val|
						li { a val[:desc], href:R(TasksNewX, key) }
					end
				end
			end
			
			def new_task_form
				task_def = Mrowka::Tasks[@type.to_sym]
				
				h2 "Nowe zadanie"
				h3 task_def[:desc]
				
				form method:'POST' do
					if task_def[:external_list] == true
						map = Hash[ Mrowka::Models::List.all.map{|l| [l.id, l.desc] } ]
						_select "Lista", 'list', map
					end
					
					task_def[:attrs].each_pair do |key, (mode, desc)|
						# TODO sucks
						if key.to_s == 'list_id'
							send mode, desc, "taskarg_#{key}", @request['from_list']
						else
							send mode, desc, "taskarg_#{key}"
						end
						br
					end
					br; br
					# TODO sucks badly
					_input "Zgłaszający", :user
					text " (#{task_def[:edits] != false ? "będziesz musiał potwierdzić zgłoszenie na swojej podstronie użytkownika" : "opcjonalne"})"
					br
					_input "Dodatkowy opis zmian (zostanie zawarty w opisie edycji bota)", :desc if task_def[:edits] != false
					br
					input type:'submit', value:"Do pracy!"
				end
			end
			
			def new_list_form
				list_def = Mrowka::Lists[@type.to_sym]
				
				h2 "Nowa lista"
				h3 list_def[:desc]
				
				form method:'POST' do
					list_def[:attrs].each_pair do |key, (mode, desc)|
						send mode, desc, "taskarg_#{key}"
						br
					end
					br; br
					_input "Zgłaszający", :user; text " (opcjonalne)"
					br
					_input "Opis listy (wymagany; będzie wyświetlony w spisie)", :desc
					br
					input type:'submit', value:"Do pracy!"
				end
			end
		end
	end
end
