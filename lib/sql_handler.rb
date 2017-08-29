module RailsSimpleSearch
  module SqlHandler  

    def init
      @table_name = @model_class.table_name
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
        column.type == :string
      else
        raise "encountered new version of Rails"
      end
    end
  
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
      @condition_group = ConditionGroup.new
      @condition_group.set_relation(:and)

      @criteria.each do |key, value|
        @condition_group.add(parse_attribute(key, value))
      end

      make_joins
    end

    def insert_condition(base_class, attribute, field, value)
      name_hash = parse_field_name(field)
      field = name_hash[:field_name]
      operator = name_hash[:operator]

      table = base_class.table_name
      key = "#{table}.#{field}"
  
      column = base_class.columns_hash[field.to_s]
      return nil unless column

      if value.nil?
        verb = 'is'
      elsif value.is_a?(Array)
        verb = 'in'
      elsif operator
        verb = operator
      elsif text_column?(column) && ! @config[:exact_match].include?((@table_name == table)? field : key)
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
      attributes = attribute.split(@config[:or_separator])
      if(attributes.size > 1)
        cg = ConditionGroup.new
        cg.set_relation(:or)
        attributes.each do |a|
          cg.add(parse_attribute(a, value))
        end
        return cg
      end

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
      @children << cg if cg
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
        condition << "#{i.field} #{i.verb}"
        if i.verb == 'in'
          condition[0] << " (?)"
        else
          condition[0] << " ?"
        end
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
