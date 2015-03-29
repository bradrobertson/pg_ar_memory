require 'bundler/setup'
require 'active_record'
require 'memory_profiler'
require 'yaml'

# CONFIG
def db_config
  conf = File.expand_path('../config/database.yml', __FILE__)

  YAML.load_file(conf)['development']
end

def schemas
  Integer(ENV['SCHEMAS'] || 50)
end

def tables
  Integer(ENV['TABLES']  || 30)
end

def env
  ENV['RACK_ENV'] || 'production'
end

# DB SETUP
def drop_db
  %x{ dropdb --if-exists #{db_config['database']} -U#{db_config['username']} }
end

def create_db
  %x{ createdb -E UTF8 #{db_config['database']} -U#{db_config['username']} } rescue nil
end

def setup_db
  puts "setting up db"

  drop_db
  create_db
end

# SCHEMA POPULATION
def create_schemas
  puts "creating schemas"

  pool = ActiveRecord::Base.establish_connection(db_config)
  connection = ActiveRecord::Base.connection

  schemas.times do |x|
    schema_name = "schema_#{x}"

    connection.execute <<-SQL
      CREATE SCHEMA IF NOT EXISTS "#{schema_name}";
    SQL

    tables.times do |y|
      connection.create_table "#{schema_name}.foos_#{y}" do |t|
        t.timestamps null: false
        t.string :name
        t.integer :some_count
        t.text :big_text
        t.json :a_bunch_of_json
      end
    end
  end

  ActiveRecord::Base.remove_connection(ActiveRecord::Base)
end

# PROFILING
def run_profiler
  puts "profiling"
  MemoryProfiler.report {
    ActiveRecord::Base.establish_connection(db_config)
    ActiveRecord::Base.configurations = {
      env => ActiveRecord::Base.connection.pool.spec.config
    }
  }.pretty_print
end

# RUN
setup_db
create_schemas
run_profiler
