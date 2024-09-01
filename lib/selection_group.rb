require_relative 'selection_item'

# frozen_string_literal: true
module RailsSimpleSearch
  module SqlHandler
    # this class is to represent a sql select statements, union of select
    # statements, or intersect of select statements
    class SelectionGroup
      def self.union_alias_count
        @union_alias_count ||= 0
        @union_alias_count += 1
        @union_alias_count
      end

      def initialize(item = nil)
        @selection_item = item if item
        @children = []
      end

      def add_child(condition_group)
        raise "It's not allowed to add child into leaf node" if leaf?

        @children << condition_group if condition_group
      end

      def add_item(selection_item)
        raise "It's not allowed to add item into non-leaf node" unless empty?

        @selection_item = selection_item
      end

      def relation(and_or)
        raise "It's no need to set relation for leaf node" if leaf?

        @relation = and_or
      end

      def leaf?
        @selection_item ? true : false
      end

      def empty?
        @children.empty? ? true : false
      end

      def to_sql
        if leaf?
          @selection_item.to_sql
        elsif @relation == :or
          unioned_sql = @children.map(&:to_sql).join(' union ')
          "select * from ( #{unioned_sql} ) as #{union_alias}"
        elsif @relation == :and
          @children.map(&:to_sql).join(' intersect ')
        else
          raise "This should not happen"
        end
      end

      def union_alias
        "union_alias_#{self.class.union_alias_count}"
      end
    end
  end
end
