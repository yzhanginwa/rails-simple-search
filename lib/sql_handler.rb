module RailsSimpleSearch
  module SqlHandler
    def init
      @model_table_name = @model_class.table_name
      @joins = {}
    end

    def run
      if pre_processor = self.class.pre_processor(@model_class.to_s)
        instance_eval(&pre_processor)
      end

      run_criteria

      query = @model_class.joins(@joins_str)
      query = query.where(@condition_group.to_ar_condition) unless @condition_group.empty?
      query.select("distinct #{@model_class.table_name}.*")
    end

    private

    def text_column?(column)
      if column.respond_to?(:text?)
        column.text?
      elsif column.respond_to?(:type)
        column.type == :string || column.type == :text
      else
        raise 'encountered new version of Rails'
      end
    end

    def make_joins
      @joins_str = ''
      joins = @joins.values
      joins.sort! { |a, b| a[0] <=> b[0] }
      joins.each do |j|
        table = j[1]
        constrain = j[2]
        @joins_str << format(" inner join #{table} AS A%02d on #{constrain}", j[0])
      end
    end

    def run_criteria
      @condition_group = ConditionGroup.new
      @condition_group.set_relation(:and)

      @criteria.each do |key, value|
        @condition_group.add(parse_search_parameters(key, value))
      end

      make_joins
    end

    def build_single_condition(base_class, association_alias, field, value)
      field, operator = parse_field_name(field)
      table = base_class.table_name
      key = "#{table}.#{field}"
      final_key = "#{association_alias}.#{field}"

      column = base_class.columns_hash[field.to_s]
      return nil unless column

      if value.nil?
        verb = 'is'
      elsif value.is_a?(Array)
        verb = 'in'
      elsif operator
        verb = operator
      elsif text_column?(column) && ! @config[:exact_match].include?((@model_table_name == table) ? field : key)
        verb = 'like'
        value = "%#{value}%"
      else
        verb = '='
      end

      ConditionGroup.new(ConditionItem.new(final_key, verb, value))
    end

    def table_name_to_alias(table_name)
      format('A%02d', @joins[table_name][0])
    end

    def insert_join(base_class, asso_ref, new_asso_chain, poly_asso_type_class=nil)
      return if asso_ref.polymorphic? && poly_asso_type_class.blank?
      base_table = base_class.table_name
      asso_table = poly_asso_type_class&.table_name || asso_ref.klass.table_name

      @join_count ||= 0
      return if base_table == asso_table
      return unless @joins[asso_table].nil?

      @join_count += 1
      base_table_alias = new_asso_chain ? base_table : table_name_to_alias(base_table)
      asso_table_alias = format('A%02d', @join_count)

      if asso_ref.belongs_to?
        if asso_ref.polymorphic?
          join_cond = "#{base_table_alias}.#{asso_ref.foreign_key} = #{asso_table_alias}.#{poly_asso_type_class.primary_key}"
          join_cond = "#{base_table_alias}.#{asso_ref.foreign_type} = '#{poly_asso_type_class.name}' and #{join_cond}"
        else
          join_cond = "#{base_table_alias}.#{asso_ref.foreign_key} = #{asso_table_alias}.#{asso_ref.klass.primary_key}"
        end
      else
        join_cond = "#{base_table_alias}.#{base_class.primary_key} = #{asso_table_alias}.#{asso_ref.foreign_key}"
        join_cond = "#{asso_table_alias}.#{asso_ref.type} = '#{base_class.name}' and #{join_cond}" if asso_ref.type
      end
      @joins[asso_table] = [@join_count, asso_table, join_cond]
    end

    # This method parse a search parameter and its value
    # then produce a ConditionGroup
    def parse_search_parameters(attribute, value)
      # handle _or_ parameters
      attributes = attribute.split(@config[:or_separator])
      if attributes.size > 1
        cg = ConditionGroup.new
        cg.set_relation(:or)
        attributes.each do |a|
          cg.add(parse_search_parameters(a, value))
        end
        return cg
      end

      # handle direct fields
      unless attribute =~ /\./
        condition = build_single_condition(@model_class, @model_class.table_name, attribute, value)
        return condition
      end

      # handle association fields
      association_fields = attribute.split(/\./)
      field = association_fields.pop

      base_class = @model_class
      new_asso_chain = true
      while (current_association_string = association_fields.shift)
        # polymorphic association with solid target table_name
        # such as 'commentable:post'
        if current_association_string.include?(':')
          poly_asso_name, poly_asso_type = current_association_string.split(':')
          current_association = base_class.reflect_on_association(poly_asso_name.to_sym)
          poly_asso_type_class = poly_asso_type.downcase.camelize.constantize
          insert_join(base_class, current_association, new_asso_chain, poly_asso_type_class)
          base_class = poly_asso_type_class
        else
          current_association = base_class.reflect_on_association(current_association_string.to_sym)
          insert_join(base_class, current_association, new_asso_chain)
          base_class = current_association.klass
        end

        new_asso_chain = false
      end

      association_alias = table_name_to_alias(base_class.table_name)
      build_single_condition(base_class, association_alias, field, value)
    end
  end

  # This class holds a single condition
  class ConditionItem
    attr_reader :field, :verb, :value

    def initialize(field, verb, value)
      @field = field
      @verb = verb
      @value = value
    end
  end

  # This class holds a ConditionGroup
  # One ConditionGroup can hold one or more
  # conditions
  class ConditionGroup
    def initialize(item = nil)
      if item
        @condition_item = item
      else
        @children = []
      end
    end

    def add(condition_group)
      raise "It's not allowed to add child into leaf node" if leaf?

      @children << condition_group if condition_group
    end

    def set_relation(and_or)
      raise "It's not needed to set relation for leaf node" if leaf?

      @relation = and_or
    end

    def leaf?
      @condition_item ? true : false
    end

    def empty?
      @children && @children.empty? ? true : false
    end

    def to_ar_condition
      condition = []
      if leaf?
        i = @condition_item
        condition << "#{i.field} #{i.verb}"
        condition[0] << (i.verb == 'in' ? ' (?)' : ' ?')
        condition << i.value
      else
        tmp_conditions = @children.map(&:to_ar_condition)
        tmp_condition_str = tmp_conditions.map(&:first).join(" #{@relation} ")
        condition << "(#{tmp_condition_str})"
        tmp_conditions.each do |t|
          (1..(t.length - 1)).each do |index|
            condition << t[index]
          end
        end
      end
      condition
    end
  end
end
