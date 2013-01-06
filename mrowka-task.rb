# coding: utf-8

MrowkaStatus = Struct.new :state, :change_total, :change_done, :error_message
MrowkaTask = Struct.new :type, :desc, :args, :status, :started, :finished, :user, :hash, :list
