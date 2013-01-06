# coding: utf-8

require 'mab'

# Define some form helpers.
module Mab::Mixin
	def _input text, name, default=''
		label text, :for=>name
		text ' '
		input name:name, id:name, value:default
	end
	
	def _text text, name, default=''
		label text, :for=>name
		text ' '
		textarea default, name:name, id:name
	end
	
	# options: {value => label}
	def _radio text, name, options, checked=0
		label text, :for=>name
		text ' '
		options.each_pair do |val, text|
			input name:name, type:'radio', value:val, id:"radio-#{name}-#{val}"
			text ' '
			label text, :for=>"radio-#{name}-#{val}"
			text ' '
		end
	end
	
	def _checkbox text, name, checked=false
		label text, :for=>name
		text ' '
		input name:name, id:name, type:'checkbox', checked:(!!checked)
	end
end
