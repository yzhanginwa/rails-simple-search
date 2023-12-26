class String
  def blank?
    nil? || empty?
  end
end

module ActiveRecord
  class Base
    def self.primary_key
      'id'
    end

    def self.reflect_on_association(association_symbol)
      ActiveRecord::Association.new(symbol_name, association_symbol)
    end
  end

  class Column
    def initialize(kind)
      @kind = kind
    end

    def type
      @kind
    end
  end

  class Query
    attr_reader :joins, :conditions, :selects

    def initialize(joins)
      @joins = joins
    end

    def where(conditions)
      @conditions = conditions
      self
    end

    def select(selects)
      @selects = selects
      self
    end
  end

  class Association
    def initialize(base_model, association_symbol)
      @base_model = base_model
      @association_symbol = association_symbol
    end

    def foreign_key
      belongs_to? ? "#{@association_symbol}_id" : "#{@base_model}_id"
    end

    def klass
      case @association_symbol
      when :posts
        Post
      when :comments
        Comment
      when :user
        User
      else
        raise 'Unknown class'
      end
    end

    def type
      case [@base_model, @association_symbol]
      when %i[user addressable]
        'addressable_type'
      end
    end

    def belongs_to?
      case [@base_model, @association_symbol]
      when %i[user posts]
        false
      when %i[post comments]
        false
      when %i[comment user]
        true
      else
        raise 'Unknown association pair'
      end
    end
  end
end

class User < ActiveRecord::Base
  def self.symbol_name
    :user
  end

  def self.table_name
    'users'
  end

  def self.columns_hash
    { 'first_name' => ActiveRecord::Column.new(:string) }
  end

  def self.joins(joins)
    ActiveRecord::Query.new(joins)
  end
end

class Post < ActiveRecord::Base
  def self.symbol_name
    :post
  end

  def self.table_name
    'posts'
  end

  def self.columns_hash
    {
      'title' => ActiveRecord::Column.new(:string),
      'body' => ActiveRecord::Column.new(:string)
    }
  end
end

class Comment < ActiveRecord::Base
  def self.symbol_name
    :comment
  end

  def self.table_name
    'comments'
  end

  def self.columns_hash
    { 'body' => ActiveRecord::Column.new(:string) }
  end
end
class Search < RailsSimpleSearch::Base
end
