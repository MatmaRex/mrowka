# coding: utf-8

module Mrowka
	Tasks = {
		# Zadanie testowe - zamiana zawartości strony.
		test: {
			desc: "Zadanie testowe",
			attrs: {
				title: [:_input, "Tytuł stony do testowania"],
				text: [:_text, "Tekst do wstawienia"],
			},
			make_list: lambda{|s, (title, text)|
				s.make_list :pages, [title.strip]
			},
			process: lambda{|s, list, interface, (title, text)|
				s.summary = interface.summary "testuje na [[#{title.strip}]]"
				
				page = list.pages[0]
				page.text = text
				page.save
				interface.increment
			},
		},
		# Generacja list.
		list: {
			desc: "Wygenerowanie listy",
			edits: false,
			attrs: {
				list_id: [:_input, "Identifikator listy"],
			},
			process: lambda{|s, dummy_list, interface, (list_id)|
				list = Mrowka::Models::List.find id: list_id.to_i
				contents = s.make_list(list.type, *list.args)
				
				list.updated = Time.now
				list.contents = contents.to_a
				list.save
				interface.increment
			},
		},
		
		# Przeniesienie / masowa zmiana kategorii.
		category_move: {
			desc: "Zmiana nazwy kategorii",
			attrs: {
				from: [:_input, "Nazwa kategorii, której zawartość chcesz przenieść (bez prefiksu Kategoria:)"],
				to: [:_input, "Nazwa kategorii docelowej (bez prefiksu Kategoria:)"],
				fullmove: [:_checkbox, "Pełne przeniesienie – skopiuj stronę kategorii pod nową nazwę i oznacz starą {{ek}}"],
			},
			make_list: lambda{|s, (from, to, fullmove)|
				from = s.cleanup_title from
				from = 'Category:'+from unless from.index(s.ns_regex_for 'category') == 0
				
				s.make_list :category, from
			},
			process: lambda{|s, list, interface, (from, to, fullmove)|
				# data comes straight from the form...
				fullmove = (fullmove=='on')
				
				from = s.cleanup_title from
				from.sub!(/^#{s.ns_regex_for 'category'}:/, '')
				
				to = s.cleanup_title to
				to.sub!(/^#{s.ns_regex_for 'category'}:/, '')
				
				# interface.summary will choose the longest possible message fitting 255 bytes of summary
				summ_intro = fullmove ? "przenosi kategorię" : "zmienia kategorię"
				s.summary = interface.summary(
					"#{summ_intro}: [[:Category:#{from}|#{from}]] → [[:Category:#{to}|#{to}]]",
					"#{summ_intro}: #{from} → #{to}",
					"#{summ_intro} [[#{to}]]",
					"#{summ_intro} #{to}"
				)
				
				if fullmove
					# move the category itself first
					f = s.page 'Category:'+from
					t = s.page 'Category:'+to

					t.text = f.text
					t.save

					f.prepend "{{ek|#{s.summary}}}"
					f.save
				end
				
				# move the articles
				list.pages_preloaded.each do |p|
					p.change_category from, to
					p.save
					interface.increment
				end
			},
		},
		category_delete: {
			desc: "Opróżnienie kategorii",
			attrs: {
				cat: [:_input, "Nazwa kategorii, którą chcesz opróżnić (bez prefiksu Kategoria:)"],
				fulldelete: [:_checkbox, "Oznacz samą kategorię {{ek}}"],
			},
			make_list: lambda{|s, (cat, fulldelete)|
				cat = s.cleanup_title cat
				cat = 'Category:'+cat unless cat.index(s.ns_regex_for 'category') == 0
				
				s.make_list :category, cat
			},
			process: lambda{|s, list, interface, (cat, fulldelete)|
				# data comes straight from the form...
				fulldelete = (fulldelete=='on')
				
				cat = s.cleanup_title cat
				cat.sub!(/^#{s.ns_regex_for 'category'}:/, '')
				
				summ_intro = fulldelete ? "usuwa kategorię" : "opróżnia kategorię"
				s.summary = interface.summary(
					"#{summ_intro}: [[:Category:#{cat}|#{cat}]]",
					"#{summ_intro}: #{cat}",
				)
				
				if fulldelete
					f = s.page 'Category:'+cat
					f.prepend "{{ek|#{s.summary}}}"
					f.save
				end
				
				list.pages_preloaded.each do |p|
					p.remove_category cat
					p.save
					interface.increment
				end
			},
		},
		
		text_replace: {
			desc: "Zamiana tekstu",
			attrs: {
				from: [:_input, "Znajdź"],
				to: [:_input, "Zamień na"],
				regex: [:_checkbox, "Wyrażenia regularne"],
			},
			external_list: true,
			process: lambda{|s, list, interface, (from, to, regex)|
				s.summary = interface.summary "zamienia tekst"
				
				list.pages_preloaded.each do |p|
					if regex == 'on'
						p.text.gsub! /#{from}/, to
					else
						p.text.gsub! from, to
					end
					
					p.save
					interface.increment
				end
			},
		},
		
		append: {
			desc: "Dopisanie tekstu na końcu",
			attrs: {
				text: [:_text, "Tekst do wstawienia na końcu strony"],
			},
			external_list: true,
			process: lambda{|s, list, interface, (text)|
				s.summary = interface.summary "dodaje stopkę"
				
				list.pages_preloaded.each do |p|
					p.append text
					p.save
					interface.increment
				end
			},
		},
		prepend: {
			desc: "Dopisanie tekstu na początku",
			attrs: {
				text: [:_text, "Tekst do wstawienia na początku strony"],
			},
			external_list: true,
			process: lambda{|s, list, interface, (text)|
				s.summary = interface.summary "dodaje nagłówek"
				
				list.pages_preloaded.each do |p|
					p.prepend text
					p.save
					interface.increment
				end
			},
		},
		
		# Purge na stronach z listy.
		purge: {
			desc: "Wykonanie akcji 'purge'",
			attrs: {},
			external_list: true,
			edits: false,
			process: lambda{|s, list, interface, dummy|
				list.to_a.each_slice(50) do |sublist|
					begin
						s.API action: 'purge', forcelinkupdate: 1, titles: sublist.join("|")
						interface.increment sublist.length
					rescue RestClient::Exception
						sublist.each do |t|
							s.API action: 'purge', forcelinkupdate: 1, titles: t
							interface.increment 1
						end
					end
				end
			},
		},
	}
end
