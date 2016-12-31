module RailsSimpleSearch
  module SqlHandler  

    def init
      @table_name = @model_class.table_name
      @joins = {}
    end

    def conditions
      run_criteria
      @conditions
    end

    def joins
      run_criteria
      @joins_str
    end

    def run
      run_criteria

      query = @model_class.joins(@joins_str)
      query = query.where(@condition_group.to_ar_condition) unless @condition_group.empty?

      if @config[:paginate]
        @count = query.count
        offset = [((@page || 0) - 1) * @config[:per_page], 0].max
        limit = @config[:per_page]
      else
        offset = @config[:offset]
        limit = @config[:limit]
      end

      query = query.order(@order) if @order
      query.select("distinct #{@model_class.table_name}.*").offset(offset).limit(limit)
    end

    private
  
    def make_joins
      @joins_str = ''
      joins = @joins.values
      joins.sort! {|a,b| a[0] <=> b[0]}
      joins.each do |j|
        table = j[1]
        constrain = j[2]
        @joins_str << " inner join  #{table} on #{constrain}" 
      end
    end
  
    def run_criteria
      return unless @conditions.nil? 
      @condition_group = ConditionGroup.new
      @condition_group.set_relation(:and)

      @criteria.each do |key, value|
        if @config[:page_name].to_s == key.to_s
          @page = value.to_i
          @criteria[key] = @page
        else
          @condition_group.add(parse_attribute(key, value))
        end
      end

      make_joins
    end

    def insert_condition(base_class, attribute, field, value)
      name_hash = parse_field_name(field)
      field = name_hash[:field_name]
      operator = name_hash[:operator]

      table = base_class.table_name
      key = "#{table}.#{field}"
  
      @conditions ||= []
      column = base_class.columns_hash[field.to_s]

      if !column.text? && value.is_a?(String)
        if column.respond_to?(:type_cast)
          value = column.type_cast(value)
        elsif column.respond_to?(:cast_type)
          if column.cast_type.respond_to?(:type_cast)
            value = column.cast_type.type_cast(value)
          elsif column.cast_type.respond_to?(:type_cast_from_user)
            value = column.cast_type.type_cast_from_user(value)
          else
            raise "something wrong!"
          end
        else
          raise "something wrong!"
        end
        @criteria[attribute] = value 
      end

      if value.nil?
        verb = 'is'
      elsif operator
        verb = operator
      elsif column.text? && ! @config[:exact_match].include?((@table_name == table)? field : key)
        verb = 'like'
        value = "%#{value}%"
      else
        verb = '='
      end

      ConditionGroup.new(ConditionItem.new(key, verb, value))
    end
  
    def insert_join(base_class, asso_ref)
      base_table = base_class.table_name
      asso_table = asso_ref.klass.table_name
      
      @join_count ||= 0
      unless base_table == asso_table
        if @joins[asso_table].nil?
          @join_count += 1
          if asso_ref.belongs_to?
            @joins[asso_table] =[@join_count, asso_table, "#{base_table}.#{asso_ref.foreign_key} = #{asso_table}.#{asso_ref.klass.primary_key}"]
          else
            join_cond = "#{base_table}.#{base_class.primary_key} = #{asso_table}.#{asso_ref.foreign_key}"
            join_cond = "#{asso_table}.#{asso_ref.type} = '#{base_class.name}' and #{join_cond}" if asso_ref.type
            @joins[asso_table] = [@join_count, asso_table, join_cond]
          end
        end
      end
    end
  
    def parse_attribute(attribute, value)
      unless attribute =~ /\./
        field = attribute
        condition = insert_condition(@model_class, attribute, field, value)
        return condition
      end 

      association_fields = attribute.split(/\./)
      field = association_fields.pop

      base_class = @model_class
      while (association_fields.size > 0) 
        association_fields[0] = base_class.reflect_on_association(association_fields[0].to_sym)
        insert_join(base_class, association_fields[0])
        base_class = association_fields.shift.klass
      end

      condition = insert_condition(base_class, attribute, field, value)
      return condition
    end
  
  end

  class ConditionItem
    attr_reader :field, :verb, :value

    def initialize(field, verb, value)
      @field = field
      @verb = verb
      @value = value
    end
  end

  class ConditionGroup
    def initialize(item=nil)
      if item
        @condition_item = item
      else
        @children = []
      end
    end

    def add(cg)
      if leaf?
        raise "It's not allowed to add child into leaf node"
      end
      @children << cg
    end

    def set_relation(and_or)
      if leaf?
        raise "It's not needed to set relation for leaf node"
      end
      @relation = and_or
    end

    def leaf?
      @condition_item ? true : false
    end

    def empty?
      (@children && @children.empty?) ? true : false
    end

    def to_ar_condition
      condition = []
      if leaf?
        i = @condition_item
        condition << "#{i.field} #{i.verb} ?"
        condition << i.value
      else
        tmp = @children.map(&:to_ar_condition)
        condition << "(" + tmp.map(&:first).join(" #{@relation} ") + ")"
        tmp.each do |t|
          (1..(t.length-1)).each do |index|
            condition << t[index]
          end
        end
      end
      condition
    end
  end
end
