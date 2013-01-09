# coding: utf-8

Mrowka = {
	tasks: {
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
		}
	}
}
