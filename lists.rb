# coding: utf-8

module Mrowka
	Lists = {
		plaintext: {
			desc: "Lista z tekstu",
			attrs: {
				text: [:_text, "Lista stron (każda w osobnej linii)"]
			}
		},
		categories_on: {
			desc: "Kategorie na stronie",
			attrs: {
				title: [:_input, "Nazwa strony"]
			}
		},
		category: {
			desc: "Zawartość kategorii (bez podkat.)",
			attrs: {
				title: [:_input, "Nazwa kategorii (z prefiksem Kategoria:)"]
			}
		},
		category_recursive: {
			desc: "Zawartość kategorii (wraz z podkat.)",
			attrs: {
				title: [:_input, "Nazwa kategorii (z prefiksem Kategoria:)"]
			}
		},
		links_on: {
			desc: "Linki na stronie",
			attrs: {
				title: [:_input, "Nazwa strony"]
			}
		},
		templates_on: {
			desc: "Szablony na stronie",
			attrs: {
				title: [:_input, "Nazwa strony"]
			}
		},
		contribs: {
			desc: "Wkład użytkownika",
			attrs: {
				title: [:_input, "Nazwa użytkownika"]
			}
		},
		whatlinkshere: {
			desc: "Linkujące",
			attrs: {
				title: [:_input, "Nazwa strony"]
			}
		},
		whatembeds: {
			desc: "Wykorzystanie szablonu",
			attrs: {
				title: [:_input, "Nazwa szablonu (z prefiksem Szablon:)"]
			}
		},
		image_usage: {
			desc: "Wykorzystanie pliku",
			attrs: {
				title: [:_input, "Nazwa pliku (z prefiksem Plik:)"]
			}
		},
		search: {
			desc: "Wyszukiwanie",
			attrs: {
				search: [:_input, "Tekst do wyszukania"]
			}
		},
		search_titles: {
			desc: "Wyszukiwanie w tytułach stron",
			attrs: {
				search: [:_input, "Tekst do wyszukania"]
			}
		},
		linksearch: {
			desc: "Wyszukiwanie linków zewn.",
			attrs: {
				search: [:_input, "Zapytanie (format jak na Specjalna:Wyszukiwarka linków)"]
			}
		},
		grep: {
			desc: "Wyszukiwanie w tytułach stron (grep; http://toolserver.org/~nikola/grep.php)",
			attrs: {
				regex: [:_input, "Wyrażenie regularne do wyszukania"]
			}
		},
	}
end
