# coding: utf-8

module Mrowka
	Tasks = {
		# Zadanie testowe - zamiana zawartości strony.
		test: {
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
		# Przeniesienie / masowa zmiana kategorii.
		category_move: {
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
	}
end
