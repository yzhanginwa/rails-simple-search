require_relative 'selection_group.rb'
require_relative 'selection_item.rb'

# This gem returns some rows of a certain table (model), according to the search parameters.
# Each search parameter can ba a direct field (like first_name, last_name), indirect
# field (like address.city, posts.comments.author.first_nane), or composite field
# (like, address.city_or_posts.comments.author.city).
#
# For example, if we have 3 search parameters, {"serach":{"aaa":"aaa"}, {"bbb.ccc":"ccc"}, {"ddd.eee_or_ggg.hhh":"hhh"}}
# The psudo result sql statement would look like:
#
#   select * from base_model
#     where aaa = 'aaa'
#
#   intersect
#
#   select * from base_model
#     join xxxxxx
#     where ccc = 'ccc'
#
#   intersect
#
#   select * from
#   (
#     select * from base_model
#       join xxxxxx
#       where eee = 'ccc'
#
#     union
#
#     select * from base_model
#       join xxxxxx
#       where hhh= 'ccc'
#   ) as union_result_1
#
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

      selection_group = generate_selection_group(@criteria)

      raw_sql = selection_group.to_sql
      if raw_sql.blank?
        @model_class.all
      else
        @model_class.from("(#{raw_sql}) AS #{@model_table_name}")
      end
    end

    private

    def generate_selection_group(criteria)
      selection_group = SelectionGroup.new
      selection_group.relation(:and)

      criteria.each do |key, value|
        sg = SelectionGroup.new
        fields = key.split(@config[:or_separator])
        if fields.size > 1
          # if the key is "or"ed by muiltiple fields
          # we generate a SelectionGroup to include all the fields
          sg.relation(:or)
          fields.each do |f|
            si = SelectionItem.new(@config, @model_class, f, value)
            sg_si = SelectionGroup.new(si)
            sg.add_child(sg_si)
          end
        else
          sg.add_item(SelectionItem.new(@config, @model_class, fields.first, value))
        end

        selection_group.add_child(sg)
      end

      selection_group
    end

    def text_column?(column)
      if column.respond_to?(:text?)
        column.text?
      elsif column.respond_to?(:type)
        column.type == :string || column.type == :text
      else
        raise 'encountered new version of Rails'
      end
    end

    def table_name_to_alias(table_name)
      format('A%02d', @joins[table_name][0])
    end
  end
end
