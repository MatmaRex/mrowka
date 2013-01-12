# coding: utf-8

require 'sequel'
require 'logger'
require_relative 'mrowka-config'

DB = Sequel.connect MrowkaConfig['database']['database']

DB.create_table? :statuses do
	primary_key :id
	
	# Current state of this task.
	# enum :state, elements: %w[waiting queued inprogress error done], default: 'waiting'
	text :state, default: 'waiting'
	# How many edits are there to make. Null when unknown (list hasn't been made yet).
	int :change_total, null: true
	# How many edits already made. 
	int :change_done, default: 0
	# Error message, if any.
	text :error_message, null: true
	
	int :task_id
end

DB.create_table? :tasks do
	primary_key :id
	
	# Type of this task.
	# enum :type, elements: %w[test append prepend category_move category_delete]
	text :type
	# Additional description added to edit summary. May be empty.
	text :desc
	# Arguments given by user. Stored serialized for convenience.
	binary :args
	# Current status of this task. TODO merge.
	int :status_id
	# Times this task has been created, and time it has been last touched.
	datetime :started
	datetime :touched
	# User who requested this task to be done.
	text :user
	# MD5 hash of all of the above, computed on task creation.
	text :md5, unique: true
	# List of articles to be edited. Stored serialized for convenience. TODO split.
	binary :list
end

module MrowkaModels; end

# Represents current progress of a task.
class MrowkaModels::Status < Sequel::Model
	one_to_one :task
end

class MrowkaModels::Task < Sequel::Model
	plugin :schema
	plugin :serialization, :marshal, :args
	plugin :serialization, :marshal, :list
	
	one_to_one :status
end

MrowkaStatus = MrowkaModels::Status
MrowkaTask = MrowkaModels::Task
