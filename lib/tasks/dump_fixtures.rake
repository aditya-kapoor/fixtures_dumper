namespace :db do
  namespace :fixtures do

    desc "Dump data from database to fixtures"
    task dump: :environment do
      require_and_execute_command
    end

    private
      def require_and_execute_command
        if defined?(Mongoid)
          require 'mongoid/dumper.rb'
          FixturesDumper::Mongoid::Dumper.dump_collections(ENV)
        else
          require 'active_record/dumper.rb'
          FixturesDumper::ActiveRecord::Dumper.dump_tables(ENV)
        end
      end
  end
end
