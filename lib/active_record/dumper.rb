require 'active_record'

module FixturesDumper
  module ActiveRecord
    class TableDoesNotExistError < StandardError; end

    class Dumper
      SYSTEM_EXCLUDED_TABLES = %w(schema_migrations delayed_jobs)

      def self.dump_tables(env_variables)
        compute_tables(env_variables)
        puts "Dumping fixtures for following tables:\n" << @actual_tables.join(", ")
        @actual_tables.each do |table_name|
          begin
            data = table_name.singularize.camelize.constantize.unscoped
            result = []
            if data.count > 0
              data.each do |record|
                result << { "#{table_name.singularize}_#{record.id}" => record.attributes }
              end
              fixture_file = fixtures_path + "/#{table_name}.yml"
              puts "Dumping #{data.count} records in #{table_name}.yml"
              File.open(fixture_file, "w") do |f|
                result.each do |hash|
                  f.write(hash.to_yaml.gsub(/^---\s+/,''))
                end
              end
            else
              puts "Table #{ table_name } has no records."
            end
          rescue NameError => ex
            puts ex.message
            next
          end
        end
      end

      def self.compute_tables(env_variables)
        set_user_excluded_tables(env_variables['EXCLUDED_TABLES'])
        ensure_table_exists!(env_variables['TABLE'])
        set_actual_tables_for_dumping(env_variables['TABLE'])
      end

      def self.set_user_excluded_tables(user_excluded_tables)
        @user_excluded_tables = user_excluded_tables
      end

      def self.ensure_table_exists!(table)
        if table && connection.tables.exclude?(table)
          raise TableDoesNotExistError.new("Table #{table} does not exist in the database.")
          exit
        end
      end

      def self.set_actual_tables_for_dumping(table)
        if table && connection.tables.include?(table)
          tables = Array.wrap(table)
        else
          tables = connection.tables
        end
        @actual_tables = tables - all_excluded_tables
      end

      def self.all_excluded_tables
        [SYSTEM_EXCLUDED_TABLES, @user_excluded_tables].flatten.compact
      end

      def self.connection
        @connection ||= ::ActiveRecord::Base.connection
      end

      def self.fixtures_path
        @fixtures_path ||= ::ActiveRecord::Tasks::DatabaseTasks.fixtures_path
      end

      private_class_method :compute_tables, :set_user_excluded_tables, :ensure_table_exists!
                           :set_actual_tables_for_dumping, :all_excluded_tables, :connection,
                           :fixtures_path
    end
  end
end