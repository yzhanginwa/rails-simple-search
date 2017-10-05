require_relative 'sql_handler'

module RailsSimpleSearch
  DEFAULT_CONFIG = { :exact_match => [], 
                     :or_separator => '_or_'
                   }

  module FixModelName
    def model_name
      ActiveModel::Name.new(self.class)
    end
  end

  class Base
    def self.inherited(subclass)
      class << subclass
         # in rails 3, the call to "form_for" invokes the model_name 
         def model_name
           ActiveModel::Name.new(self)
         end
      end
     
      # to fix an issues in rails 4.2
      subclass.send(:include, RailsSimpleSearch::FixModelName)
    end
 
    def self.pre_process(model_name, &procedure)
      @pre_processors ||= {}
      @pre_processors[model_name] = procedure
    end

    def self.pre_processor(model_name)
      @pre_processors ||= {}
      @pre_processors[model_name]
    end

    def initialize(model_class, criteria={}, config={})
      @criteria = sanitize_criteria(criteria)
      @config = DEFAULT_CONFIG.merge(config)
      @config[:exact_match] = [@config[:exact_match]] unless @config[:exact_match].respond_to?(:map!)
      @config[:exact_match].map!{|em| em.to_s}

      @model_class = (model_class.is_a?(Symbol) || model_class.is_a?(String))? model_class.to_s.camelize.constantize : model_class
      load_database_handler(@model_class)
      init
    end

    def load_database_handler(model_class)
      if model_class.ancestors.include?(ActiveRecord::Base)
        RailsSimpleSearch::Base.send(:include, RailsSimpleSearch::SqlHandler)
      else
        raise("RailsSimpleSearch only supports ActiveRecord for now")
      end
    end
  
    def count
      @count || 0
    end

    def add_conditions(h={})
      @criteria.merge!(h.stringify_keys)
    end
  
    def remove_criteria(key)
      @criteria.delete(key.to_s)
    end

    def append_criteria(key, value)
      @criteria[key.to_s] = value
    end

    private 

    def method_missing(method, *args)
      method_str = method.to_s
      if method_str =~ /^([^=]+)=$/
        @criteria[$1.to_s] = args[0]
      else 
        @criteria[method_str]
      end
    end

    def parse_field_name(name)
      result = {}
      if name =~ /^(.*)?((_(greater|less)_than)(_equal_to)?)$/
        result[:field_name] = $1
        if $4 == 'greater'
          result[:operator] = ">"
        else
          result[:operator] = "<"
        end
        if $5
          result[:operator] << "="
        end
      else
        result[:field_name] = name
      end
      result
    end
  
    def sanitize_criteria(criteria)
      criteria = criteria || {}
      c = {}
      criteria.each do |key, value|
        unless value.blank?
          c[key] = value
        end
      end
      c.stringify_keys
    end
  end
end
