require_relative 'sql_handler'

module RailsSimpleSearch
  DEFAULT_CONFIG = { :exact_match => [], 
                     :paginate => true, 
                     :page_name => 'page', 
                     :offset => 0,
                     :limit => 1000, 
                     :per_page => 20
                   }

  module FixModelName
    def model_name
      ActiveModel::Name.new(self.class)
    end
  end

  class Base
    def self.inherited(subclass)
      class << subclass
         # in rails 3, the call to "form_for" invokes the mode_name 
         def model_name
           ActiveModel::Name.new(self)
         end
      end
     
      # to fix an issues in rails 4.2
      subclass.send(:include, RailsSimpleSearch::FixModelName)
    end
 
    def initialize(model_class, criteria={}, config={})
      @criteria = sanitize_criteria(criteria)
      @config = DEFAULT_CONFIG.merge(config)

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

    def pages
      (count == 0)? 0 : (count * 1.0 / @config[:per_page]).ceil 
    end

    def pages_for_select
      (1..pages).to_a
    end

    def order=(str)
      @order = str
    end
  
    def add_conditions(h={})
      @criteria.merge!(h)
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
      if name =~ /^(.*)?((_(greater|less)_than)(_or_equal_to)?)$/
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
      c
    end
  end
end
