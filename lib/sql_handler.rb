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
      if @conditions
        query = query.where(@conditions)
      end

      if @config[:paginate]
        @count = query.count
        offset = [((@page || 0) - 1) * @config[:per_page], 0].max
        limit = @config[:per_page]
      else
        offset = @config[:offset]
        limit = @config[:limit]
      end

      query.order(@order) if @order
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
      @criteria.each do |key, value|
        if @config[:page_name].to_s == key.to_s
          @page = value.to_i
          @criteria[key] = @page
        else
          parse_attribute(key, value)
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
        value = column.type_cast(value)
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

      if @conditions.size < 1
        @conditions[0] = "#{key} #{verb} ?"
        @conditions[1] = value
      else
        @conditions[0] += " and #{key} #{verb} ?"
        @conditions << value
      end
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
        insert_condition(@model_class, attribute, field, value)
        return
      end 

      association_fields = attribute.split(/\./)
      field = association_fields.pop

      base_class = @model_class
      while (association_fields.size > 0) 
        association_fields[0] = base_class.reflect_on_association(association_fields[0].to_sym)
        insert_join(base_class, association_fields[0])
        base_class = association_fields.shift.klass
      end

      insert_condition(base_class, attribute, field, value)
    end
  
  end
end
