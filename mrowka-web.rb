# coding: utf-8

require_relative 'mrowka-defs'

require 'camping'

require_relative 'filebackend'
require_relative 'mrowka-task'
require_relative 'mab-forms'

$db = FileBackend.new 'data-marshal', 'data-marshal.lock'
$dbarchive = FileBackend.new 'dataarchive-marshal', 'dataarchive-marshal.lock'

$db.write([]) if !$db.exist?
$dbarchive.write([]) if !$dbarchive.exist?

Camping.goes :MrowkaWeb
module MrowkaWeb
	module Controllers
		class Index
			def get
				render :index
			end
		end
		
		class Tasks
			def get
				@tasks = $db.read + $dbarchive.read
				render :tasks
			end
		end
		
		class New
			def get
				render :new_task_list
			end
		end
		
		class NewX
			def get type
				@type = type.to_sym
				render :new_task_form
			end
			def post type
				type = type.to_sym
				
				$db.transact do |data|
					status = MrowkaStatus.new :waiting, nil, 0
					args = Mrowka[:tasks][type.to_sym][:attrs].map{|key, val| @request["taskarg_#{key}"] }
					
					task = MrowkaTask.new type, @request[:desc], args, status, Time.now, nil, @request[:user], "hash placeholder", nil
					task.hash = Digest::MD5.hexdigest(task.inspect)
					
					data.push task unless data.find{|d| d.hash == task.hash }
					data
				end
				
				redirect Tasks
			end
		end
	end
	
	module Views
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
				li { a "zgłosić nową robótkę", href: R(New) }
			end
		end
		
		def tasks
			# TODO move to i18n file
			readable_type_map = {
				test: "Zadanie testowe",
				append: "Dopisanie tekstu",
				prepend: "Dopisanie tekstu na początku",
				category_move: "Zmiana nazwy kategorii",
				category_delete: "Opróżnienie kategorii",
			}
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
						td readable_type_map[task.type]
						td task.desc
						td do
							dl do
								Mrowka[:tasks][task.type][:attrs].keys.zip(task.args) do |key, val|
									dt key
									dd val
								end
							end
						end
						td "#{task.started.to_s} przez #{task.user}"
						td "#{readable_status_map[task.status.state]} #{task.status.state == :error ? task.status.error_message : nil} (#{task.status.change_done}/#{task.status.change_total || '?'})"
						td {
							text task.hash
							text ' '
							_confirm_form task if task.status.state == :waiting
						}
					end
				end
			end
		end
		
		def _confirm_form task
			_field = lambda{|k,v| input type:'hidden', name:k, value:v }
			
			form style:'display:inline', method:"POST", action:"https://pl.wikipedia.org/w/index.php" do
				_field.call 'title', "Wikipedysta:#{task.user}/mrówka.js"
				_field.call 'action', 'edit'
				_field.call 'wpSummary', "potwierdzenie zgłoszenia #{task.hash}"
				_field.call 'wpTextbox1', task.hash.to_s
				
				input type:'submit', value:'potwierdź'
			end
		end
		
		def new_task_list
			# TODO move to i18n file
			readable_type_map = {
				test: "Zadanie testowe",
				append: "Dopisanie tekstu",
				prepend: "Dopisanie tekstu na początku",
				category_move: "Zmiana nazwy kategorii",
				category_delete: "Opróżnienie kategorii",
			}
			
			h2 "Nowe zadanie"
			ul do
				Mrowka[:tasks].each_pair do |key, val|
					li { a readable_type_map[key], href:R(NewX, key) }
				end
			end
		end
		
		def new_task_form
			h2 "Nowe zadanie"
			h3 @type
			
			form method:'POST' do
				Mrowka[:tasks][@type][:attrs].each_pair do |key, (mode, desc)|
					send mode, desc, "taskarg_#{key}"
					br
				end
				br; br
				_input "Zgłaszający", :user; text " (będziesz musiał potwierdzić zgłoszenie na swojej stronie użytkownika)"
				br
				_input "Dodatkowy opis zmian", :desc
				br
				input type:'submit', value:"Do pracy!"
			end
		end
	end
end
