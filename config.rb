# coding: utf-8

require 'inifile'
module Mrowka
	Config = IniFile.load 'config.ini', encoding: 'utf-8'
end
