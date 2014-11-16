require 'mongoid'

module FixturesDumper
  module Mongoid
    class CollectionDoesNotExistError < StandardError; end

    class Dumper
      SYSTEM_EXCLUDED_COLLECTIONS = %w(delayed_jobs)

      def self.dump_collections(env_variables)
        compute_collections(env_variables)
        puts "Dumping fixtures for following collections:\n" << @actual_collections.join(", ")
        @actual_collections.each do |collection|
          begin
            data = collection.singularize.camelize.constantize.unscoped
            result = []
            if data.count > 0
              data.each do |record|
                result << { "#{collection.singularize}_#{record.id}" => normalize_record_attrs(record) }
              end
              fixture_file = fixtures_path + "/#{collection}.yml"
              puts "Dumping #{data.count} records in #{collection}.yml"
              File.open(fixture_file, "w") do |f|
                result.each do |hash|
                  f.write(hash.to_yaml.gsub(/^---\s+/,'').gsub('!ruby/hash:BSON::Document', ''))
                end
              end
            else
              puts "Collection #{collection} has no records."
            end
          rescue NameError => ex
            puts ex.message
            next
          end
        end
      end

      def self.compute_collections(env_variables)
        set_user_excluded_collections(env_variables['EXCLUDED_TABLES'])
        ensure_collection_exists!(env_variables['TABLE'])
        set_actual_collections_for_dumping(env_variables['TABLE'])
      end

      def self.set_user_excluded_collections(user_excluded_collections)
        @user_excluded_collections = user_excluded_collections
      end

      def self.normalize_record_attrs(record)
        duped_attributes = record.attributes.dup
        duped_attributes.each do |attribute, attribute_value|
          duped_attributes[attribute] = attribute_value.to_s if attribute_value.is_a?(::BSON::ObjectId)
        end
        duped_attributes.to_hash
      end

      def self.ensure_collection_exists!(collection)
        if collection && mongoid_collections.exclude?(collection)
          raise CollectionDoesNotExistError.new("Collection #{collection} does not exist in the database.")
          exit
        end
      end

      def self.set_actual_collections_for_dumping(collection)
        @actual_collections = compute_total_collections(collection) - all_excluded_collections
      end

      def self.compute_total_collections(collection)
        if collection && mongoid_collections.include?(collection)
          Array.wrap(collection)
        else
          mongoid_collections
        end
      end

      def self.all_excluded_collections
        [SYSTEM_EXCLUDED_COLLECTIONS, @user_excluded_collections].flatten.compact
      end

      def self.mongoid_collections
        @mongoid_collections ||= ::Mongoid.default_session.collections.collect(&:name)
      end

      def self.fixtures_path
        if ENV['FIXTURES_PATH']
          File.join(::Rails.root, ENV['FIXTURES_PATH'])
        else
          File.join(::Rails.root, 'test', 'fixtures')
        end
      end

      private_class_method :compute_collections, :set_user_excluded_collections,
                           :normalize_record_attrs, :ensure_collection_exists!,
                           :set_actual_collections_for_dumping, :compute_total_collections,
                           :all_excluded_collections, :mongoid_collections,
                           :fixtures_path
    end
  end
end