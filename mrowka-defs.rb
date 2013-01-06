# coding: utf-8

Mrowka = {
	tasks: {
		test: {
			attrs: {
				title: [:_input, "Tytuł stony do testowania"],
				text: [:_text, "Tekst do wstawienia"],
			},
			summary: lambda{|(title, text)|
				"testuje na [[#{title}]]"
			},
			make_list: lambda{|s, (title, text)|
				s.make_list :pages, [title]
			},
			process: lambda{|s, list, progress, (title, text)|
				page = list.pages[0]
				page.text = text
				page.save
				progress.increment
			},
		}
	}
}
